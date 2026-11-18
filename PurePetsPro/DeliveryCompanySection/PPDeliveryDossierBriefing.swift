import SwiftUI
import Combine
import CoreLocation
import CoreFoundation

private func briefingText(_ key: String) -> String { Language.get(key, alter: nil) }
private func briefingFormat(_ key: String, _ arguments: CVarArg...) -> String {
    String(format: briefingText(key), locale: Locale(identifier: Language.currentLanguageCode()), arguments: arguments)
}
private func briefingNumber(_ number: NSNumber) -> String {
    let formatter = NumberFormatter()
    formatter.locale = Locale(identifier: Language.currentLanguageCode())
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 0
    return formatter.string(from: number) ?? number.stringValue
}

/// Values copied from the authorized dossier, not geocoded labels or device GPS.
struct PPDeliveryDossierRouteInput: Hashable, Sendable {
    struct Point: Hashable, Sendable {
        let latitude: Double
        let longitude: Double
        init?(_ coordinate: CLLocationCoordinate2D?) {
            guard let coordinate, PPGoogleMapsRouteService.isUsable(coordinate) else { return nil }
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        }
        var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
    }
    let requestID: String
    let pickup: Point?
    let dropoff: Point?
    let language: String
    let retry: Int

    @MainActor
    init(record: PPDeliveryRequestRecord, retry: Int) {
        requestID = record.requestID
        pickup = Point(ppParseDriverAddress(record.pickupAddress).coordinate)
        dropoff = Point(ppParseDriverAddress(record.dropoffAddress).coordinate)
        language = Language.currentLanguageCode()
        self.retry = retry
    }
}

private struct PPDeliveryDossierDrivingMetrics: Sendable {
    let distanceMeters: Int
    let durationSeconds: Int

    init?(_ response: [AnyHashable: Any]?) {
        guard let response, let version = response["version"] as? NSNumber,
              CFGetTypeID(version) != CFBooleanGetTypeID(), version == 1,
              let routes = response["routes"] as? [[String: Any]],
              let route = routes.first(where: { $0["kind"] as? String == "stops" }),
              route["unavailable"] as? Bool != true,
              let distance = route["distanceMeters"] as? NSNumber,
              let duration = route["durationSeconds"] as? NSNumber,
              CFGetTypeID(distance) != CFBooleanGetTypeID(), CFGetTypeID(duration) != CFBooleanGetTypeID(),
              distance.doubleValue.isFinite, (0...2_000_000).contains(distance.doubleValue),
              distance.doubleValue.rounded(.down) == distance.doubleValue,
              duration.doubleValue.isFinite, (0...172_800).contains(duration.doubleValue) else { return nil }
        distanceMeters = distance.intValue
        durationSeconds = Int(duration.doubleValue.rounded())
    }
}

private enum PPDeliveryDossierRouteFailure: Error { case unavailable, timedOut }

/// First terminal event wins, including cancellation before the callback is installed.
/// A wall-clock deadline also finishes the task if the SDK never calls its completion.
private final class PPDeliveryDossierRouteRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<PPDeliveryDossierDrivingMetrics, Error>?
    private var outcome: Result<PPDeliveryDossierDrivingMetrics, Error>?
    private var deadline: DispatchWorkItem?

    func install(_ continuation: CheckedContinuation<PPDeliveryDossierDrivingMetrics, Error>) -> Bool {
        lock.lock()
        if let outcome {
            lock.unlock()
            continuation.resume(with: outcome)
            return false
        }
        self.continuation = continuation
        let deadline = DispatchWorkItem { [weak self] in self?.finish(.failure(PPDeliveryDossierRouteFailure.timedOut)) }
        self.deadline = deadline
        lock.unlock()
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 20, execute: deadline)
        return true
    }

    func finish(_ result: Result<PPDeliveryDossierDrivingMetrics, Error>) {
        lock.lock()
        guard outcome == nil else { lock.unlock(); return }
        outcome = result
        let continuation = self.continuation
        self.continuation = nil
        let deadline = self.deadline
        self.deadline = nil
        lock.unlock()
        deadline?.cancel()
        continuation?.resume(with: result)
    }
}

/// The sheet's .task(id:) owns loading, cancellation and replacement by newer saved stops.
@MainActor
final class PPDeliveryDossierRouteEstimate: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, missingPoints, unavailable
        case ready(distance: String, duration: String)
    }
    @Published private(set) var phase: Phase = .idle
    private var activeInput: PPDeliveryDossierRouteInput?
    private var generation: UInt = 0
    private var cached: (input: PPDeliveryDossierRouteInput, phase: Phase, fetchedAt: Date)?

    func load(_ input: PPDeliveryDossierRouteInput?) async {
        generation &+= 1
        let loadGeneration = generation
        activeInput = input
        guard let input else { phase = .idle; return }
        guard !input.requestID.isEmpty, let pickup = input.pickup, let dropoff = input.dropoff else {
            phase = .missingPoints
            return
        }
        if let cached, cached.input == input {
            let age = Date().timeIntervalSince(cached.fetchedAt)
            if age >= 0 && age < 180 { phase = cached.phase; return }
        }
        phase = .loading
        do {
            try Task.checkCancellation()
            let request = PPDeliveryDossierRouteRequest()
            let metrics = try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    guard request.install(continuation) else { return }
                    guard !Task.isCancelled else { request.finish(.failure(CancellationError())); return }
                    PPDeliveryService.shared().fetchDrivingRoute(
                        pickup: ["latitude": pickup.latitude, "longitude": pickup.longitude],
                        dropoff: ["latitude": dropoff.latitude, "longitude": dropoff.longitude]
                    ) { response, error in
                        if let error { request.finish(.failure(error)); return }
                        guard let metrics = PPDeliveryDossierDrivingMetrics(response) else {
                            request.finish(.failure(PPDeliveryDossierRouteFailure.unavailable))
                            return
                        }
                        request.finish(.success(metrics))
                    }
                }
            } onCancel: {
                request.finish(.failure(CancellationError()))
            }
            guard generation == loadGeneration, activeInput == input else { return }
            try Task.checkCancellation()
            let isArabic = input.language.hasPrefix("ar")
            let result = Phase.ready(
                distance: PPGoogleMapsRouteService.shared.formatDistance(meters: metrics.distanceMeters, isArabic: isArabic),
                duration: PPGoogleMapsRouteService.shared.formatDuration(seconds: metrics.durationSeconds, isArabic: isArabic))
            cached = (input, result, Date())
            phase = result
        } catch {
            guard generation == loadGeneration, activeInput == input else { return }
            phase = Task.isCancelled || error is CancellationError ? .idle : .unavailable
        }
    }
}

struct PPDeliveryDossierRouteFacts: View {
    let phase: PPDeliveryDossierRouteEstimate.Phase
    let onRetry: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: AdminSpacing.base))
                : AnyLayout(HStackLayout(alignment: .top, spacing: AdminSpacing.lg))
            layout {
                metric("DeliveryDetail_RoadDistance", symbol: "point.topleft.down.to.point.bottomright.curvepath", value: values?.0)
                metric("DeliveryDetail_DrivingTime", symbol: "clock", value: values?.1)
            }
            switch phase {
            case .idle:
                Button(action: onRetry) { Text(briefingText("DeliveryDetail_Estimate_Calculate")) }
                    .font(AdminType.subheadlineBold).foregroundStyle(AdminSurface.primary)
                    .frame(minHeight: AdminTouchTarget.minimum)
            case .loading:
                HStack(spacing: AdminSpacing.sm) {
                    ProgressView().tint(AdminSurface.secondaryText).accessibilityHidden(true)
                    Text(briefingText("DeliveryDetail_Estimate_Loading"))
                }
                .font(AdminType.caption1)
                .foregroundStyle(AdminSurface.secondaryText)
            case .missingPoints:
                Text(briefingText("DeliveryDetail_Estimate_MissingPoints"))
                    .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
            case .unavailable:
                VStack(alignment: .leading, spacing: AdminSpacing.xs) {
                    Text(briefingText("DeliveryDetail_Estimate_Unavailable"))
                        .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
                    Button(action: onRetry) { Text(briefingText("DeliveryDetail_Estimate_Retry")) }
                        .font(AdminType.subheadlineBold).foregroundStyle(AdminSurface.primary)
                        .frame(minHeight: AdminTouchTarget.minimum)
                }
            case .ready:
                Text(briefingText("DeliveryDetail_Estimate_Scope"))
                    .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityIdentifier("delivery_dossier_route_metrics")
    }

    private var values: (String, String)? {
        if case let .ready(distance, duration) = phase { return (distance, duration) }
        return nil
    }

    private func metric(_ title: String, symbol: String, value: String?) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.xs) {
            Label(briefingText(title), systemImage: symbol)
                .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
            Text(ppDriverIsolated(value ?? briefingText("DeliveryDetail_Estimate_Unknown")))
                .font(AdminType.headline).monospacedDigit().foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

struct PPDeliveryDossierManifest: View {
    let available: Bool
    let items: [PPDeliveryManifestItem]
    let lineCount: UInt
    let truncated: Bool
    @Binding var expanded: Bool
    let refreshing: Bool
    let onRefresh: () -> Void

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            if !available {
                Text(briefingText("DeliveryDetail_Manifest_Unavailable"))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onRefresh) { Text(briefingText("DeliveryDetail_Manifest_Retry")) }
                    .font(AdminType.subheadlineBold).foregroundStyle(AdminSurface.primary)
                    .frame(minHeight: AdminTouchTarget.minimum)
                    .disabled(refreshing)
            } else if items.isEmpty {
                Text(briefingText("DeliveryDetail_Manifest_Empty"))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVStack(alignment: .leading, spacing: AdminSpacing.base) {
                    if truncated {
                        Label(briefingFormat("DeliveryDetail_Manifest_Partial",
                                            briefingNumber(NSNumber(value: items.count)), briefingNumber(NSNumber(value: lineCount))),
                              systemImage: "exclamationmark.triangle")
                            .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                    }
                    ForEach(items, id: \.lineID) { item in
                        manifestLine(item)
                        if item.lineID != items.last?.lineID {
                            Rectangle().fill(AdminSurface.hairline).frame(height: 0.5).accessibilityHidden(true)
                        }
                    }
                }
                .padding(.top, AdminSpacing.xs)
            }
        } label: {
            HStack(alignment: .center, spacing: AdminSpacing.sm) {
                Image(systemName: "shippingbox").accessibilityHidden(true)
                VStack(alignment: .leading, spacing: AdminSpacing.xs) {
                    Text(briefingText("DeliveryDetail_Manifest_Title")).font(AdminType.subheadlineBold)
                    Text(available ? briefingFormat("DeliveryDetail_Manifest_Count", briefingNumber(NSNumber(value: lineCount)))
                         : briefingText("DeliveryDetail_Manifest_Unknown"))
                        .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .disclosureGroupStyle(PPDeliveryManifestPillStyle())
        .accessibilityIdentifier("delivery_dossier_manifest")
    }

    private func manifestLine(_ item: PPDeliveryManifestItem) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.sm) {
            Text(localized(item.nameAr, item.nameEn).isEmpty
                 ? briefingText("DeliveryDetail_Manifest_Item") : localized(item.nameAr, item.nameEn))
                .font(AdminType.bodyBold).foregroundStyle(AdminSurface.primaryText)
                .fixedSize(horizontal: false, vertical: true)
            Text(item.quantity.map { briefingFormat("DeliveryDetail_Manifest_Quantity", briefingNumber($0)) }
                 ?? briefingText("DeliveryDetail_Manifest_QuantityUnknown"))
                .font(AdminType.subheadline).foregroundStyle(AdminSurface.secondaryText)
            if !item.variant.isEmpty {
                Text(item.variant).font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ForEach(Array(item.options.enumerated()), id: \.offset) { _, option in
                VStack(alignment: .leading, spacing: AdminSpacing.xs) {
                    Text(localized(option.nameAr, option.nameEn)).font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
                    Text(localized(option.valueAr, option.valueEn)).font(AdminType.subheadline).foregroundStyle(AdminSurface.primaryText)
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
            }
            if item.optionsTruncated {
                Text(briefingText("DeliveryDetail_Manifest_OptionsPartial"))
                    .font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func localized(_ ar: String, _ en: String) -> String {
        Language.isRTL() ? (ar.isEmpty ? en : ar) : (en.isEmpty ? ar : en)
    }
}

private struct PPDeliveryManifestPillStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: AdminSpacing.base) {
            Button { configuration.isExpanded.toggle() } label: {
                HStack(spacing: AdminSpacing.sm) {
                    configuration.label
                    Image(systemName: "chevron.down")
                        .font(AdminType.caption1)
                        .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .foregroundStyle(AdminSurface.primaryText)
                .padding(.horizontal, AdminSpacing.base).padding(.vertical, AdminSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: AdminTouchTarget.minimum)
                .background(AdminSurface.backgroundSecondary, in: Capsule())
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityValue(briefingText(configuration.isExpanded ? "DeliveryDetail_Manifest_Expanded" : "DeliveryDetail_Manifest_Collapsed"))
            if configuration.isExpanded { configuration.content }
        }
    }
}
