// Pure Pets Pro — selected-stop road route, review and navigation.
// Delivery identity and lifecycle remain owned by the calling workspace.

import SwiftUI
import CoreLocation
import UIKit

enum PPDeliveryRouteStop: Int, CaseIterable, Sendable, Hashable {
    case pickup
    case dropoff
    case storeToCustomer
}

@MainActor
struct PPInAppRouteModalView: View {
    let orderNumber: String
    let pickupAddress: PPDriverAddress
    let dropoffAddress: PPDriverAddress
    let initialStop: PPDeliveryRouteStop
    let onClose: @Sendable @MainActor () -> Void

    @StateObject private var tracker = PPDriverLocationTracker.shared
    @State private var selectedStop: PPDeliveryRouteStop
    @State private var mapStyle: PPMapStyleType = .roadmap
    @State private var routeInfo: PPRouteInfo?
    @State private var phase: RoutePhase = .locating
    @State private var pickupCoordinate: CLLocationCoordinate2D?
    @State private var dropoffCoordinate: CLLocationCoordinate2D?
    @State private var pickupResolvedQuery = ""
    @State private var dropoffResolvedQuery = ""
    @State private var loadedRequestID: RouteRequestID?
    @State private var routeRevision = 0
    @State private var retryRevision = 0
    @State private var fitTrigger = 0
    @State private var locationTrigger = 0
    @State private var focusTrigger = 0
    @State private var focusedCoordinate: CLLocationCoordinate2D?
    @State private var pendingStep: PPRouteStep?
    @State private var pendingStepRequestID: RouteRequestID?
    @State private var showsReview = false
    @State private var mapFailed = false
    @State private var mapRevision = 0
    @State private var openingMaps = false
    @State private var handoffFailed = false
    @State private var copied = false
    @State private var copyRevision = 0
    @AccessibilityFocusState private var reviewFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private enum RoutePhase {
        case locating, locationUnavailable, locationDenied, addressUnavailable, loading, ready
        case failed(PPRouteServiceError)
    }

    private struct RouteRequestID: Hashable {
        let order: String
        let pickupQuery: String
        let dropoffQuery: String
        let stop: PPDeliveryRouteStop
        let retry: Int
        let hasLocation: Bool
        let authorization: Int
        let active: Bool
    }

    init(orderNumber: String, pickupAddress: PPDriverAddress, dropoffAddress: PPDriverAddress,
         initialStop: PPDeliveryRouteStop = .pickup,
         onClose: @escaping @Sendable @MainActor () -> Void) {
        self.orderNumber = orderNumber
        self.pickupAddress = pickupAddress
        self.dropoffAddress = dropoffAddress
        self.initialStop = initialStop
        self.onClose = onClose
        _selectedStop = State(initialValue: initialStop)
    }

    init(task: PPDriverTask, onClose: @escaping @Sendable @MainActor () -> Void) {
        self.init(orderNumber: task.orderNumber, pickupAddress: task.pickup, dropoffAddress: task.dropoff,
                  initialStop: task.stage <= .toPickup ? .pickup : .dropoff, onClose: onClose)
    }

    init(order: PPDeliveryOrderModel, onClose: @escaping @Sendable @MainActor () -> Void) {
        let canReveal = order.pp_canRevealExactDeliveryLocation()
        let pickup = PPDriverAddress(primary: order.branchName ?? order.pp_pickupLocationSummary(),
                                     secondary: order.pickupAddress ?? "",
                                     mapQuery: order.pp_pickupMapQuery(), phone: "")
        let exactQuery = [order.deliveryLocationPoint ?? "", order.deliveryAddress]
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
        let dropoff = PPDriverAddress(
            primary: canReveal ? order.pp_exactDeliveryLocationText() : order.pp_deliveryAreaSummary(),
            secondary: "", mapQuery: canReveal ? exactQuery : "", phone: "")
        let atPickup = ["ready_to_ship", "readytoship", "requested", "assigned", "awaiting_handover"]
            .contains((order.deliveryStatus ?? "").lowercased())
        self.init(orderNumber: order.bestOrderNumber(), pickupAddress: pickup, dropoffAddress: dropoff,
                  initialStop: atPickup ? .pickup : .dropoff, onClose: onClose)
    }

    private var isArabic: Bool { Language.isRTL() }
    private var activeAddress: PPDriverAddress {
        switch selectedStop {
        case .pickup: return pickupAddress
        case .dropoff, .storeToCustomer: return dropoffAddress
        }
    }
    private var activeCoordinate: CLLocationCoordinate2D? {
        switch selectedStop {
        case .pickup: return visiblePickupCoordinate
        case .dropoff, .storeToCustomer: return visibleDropoffCoordinate
        }
    }
    private var visiblePickupCoordinate: CLLocationCoordinate2D? {
        if selectedStop == .storeToCustomer { return pickupCoordinate }
        return !pickupAddress.mapQuery.isEmpty && pickupResolvedQuery == pickupAddress.mapQuery ? pickupCoordinate : nil
    }
    private var visibleDropoffCoordinate: CLLocationCoordinate2D? {
        if selectedStop == .storeToCustomer { return dropoffCoordinate }
        return !dropoffAddress.mapQuery.isEmpty && dropoffResolvedQuery == dropoffAddress.mapQuery ? dropoffCoordinate : nil
    }
    private var visibleRouteInfo: PPRouteInfo? { loadedRequestID == routeRequestID ? routeInfo : nil }
    private var canOpenDestination: Bool {
        if selectedStop == .storeToCustomer {
            let pQ = [pickupAddress.mapQuery, pickupAddress.secondary, pickupAddress.primary].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
            let dQ = [dropoffAddress.mapQuery, dropoffAddress.secondary, dropoffAddress.primary].first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ?? ""
            return !pQ.isEmpty && !dQ.isEmpty
        }
        return !activeAddress.mapQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var routeRequestID: RouteRequestID {
        RouteRequestID(order: orderNumber, pickupQuery: pickupAddress.mapQuery,
                       dropoffQuery: dropoffAddress.mapQuery, stop: selectedStop,
                       retry: retryRevision, hasLocation: tracker.usableLocation != nil,
                       authorization: Int(tracker.authorizationStatus.rawValue), active: scenePhase == .active)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                navigationHeader
                mapCanvas
                    .frame(minHeight: 96, maxHeight: .infinity)
                ScrollView {
                    destinationDock
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                }
                .frame(maxHeight: min(geometry.size.height * 0.52, dynamicTypeSize.isAccessibilitySize ? 420 : 332))
                .background(AdminSurface.card)
                .overlay(alignment: .top) { Rectangle().fill(AdminSurface.hairline).frame(height: 0.5) }
            }
        }
        .background(AdminSurface.background.ignoresSafeArea())
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.currentLanguageCode()))
        .onAppear { tracker.startTracking() }
        .onDisappear { tracker.stopTracking() }
        .onChange(of: scenePhase) { _, value in
            if value == .active { tracker.startTracking() } else { tracker.stopTracking() }
        }
        .task(id: routeRequestID) { await loadSelectedRoute() }
        .task(id: copyRevision) {
            guard copyRevision > 0 else { return }
            do { try await Task.sleep(for: .seconds(3)); copied = false } catch { }
        }
        .sheet(isPresented: $showsReview, onDismiss: finishReview) { routeReview }
    }

    private var navigationHeader: some View {
        HStack(spacing: 12) {
            iconButton("xmark", label: ppDriverText("DriverCockpit_LiveRoute_Close"), action: onClose)
            VStack(alignment: .leading, spacing: 2) {
                Text(ppDriverText("ProRoute_Title"))
                    .font(AdminType.headlineBold)
                    .accessibilityAddTraits(.isHeader)
                if !orderNumber.isEmpty {
                    Text(ppDriverIsolated(orderNumber))
                        .font(AdminType.caption1)
                        .foregroundStyle(AdminSurface.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Menu {
                ForEach(PPMapStyleType.allCases, id: \.self) { style in
                    Button { mapStyle = style } label: {
                        Label(styleLabel(style), systemImage: style == mapStyle ? "checkmark" : "map")
                    }
                }
            } label: {
                Image(systemName: "map")
                    .font(.system(size: 19, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(AdminSurface.backgroundSecondary, in: Circle())
            }
            .accessibilityLabel(ppDriverText("ProRoute_MapStyle"))
            .accessibilityValue(styleLabel(mapStyle))
        }
        .foregroundStyle(AdminSurface.primaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(AdminSurface.card)
    }

    private var mapCanvas: some View {
        ZStack(alignment: .topTrailing) {
            PPInAppGoogleMapView(
                pickupCoordinate: visiblePickupCoordinate, dropoffCoordinate: visibleDropoffCoordinate,
                polylineCoordinates: visibleRouteInfo?.polylineCoordinates ?? [],
                driverCoordinate: tracker.usableLocation?.coordinate,
                driverHeading: tracker.currentHeading.map { $0.trueHeading >= 0 ? $0.trueHeading : $0.magneticHeading },
                mapStyle: mapStyle,
                pickupTitle: ppDriverText("DriverCockpit_LiveRoute_PickupStop"),
                dropoffTitle: ppDriverText("DriverCockpit_LiveRoute_DropoffStop"),
                driverTitle: ppDriverText("ProRoute_YourLocation"),
                isArabic: isArabic, isDarkMode: colorScheme == .dark,
                recenterTrigger: fitTrigger, routeRevision: routeRevision,
                locationTrigger: locationTrigger, focusTrigger: focusTrigger,
                focusedCoordinate: focusedCoordinate, reduceMotion: reduceMotion,
                onMapFailure: { mapFailed = true }, onMapReady: { mapFailed = false }
            )
            .id("\(colorScheme)-\(mapRevision)")
            .accessibilityLabel(ppDriverText("ProRoute_MapAccessibility"))
            VStack(spacing: 8) {
                iconButton("viewfinder", label: ppDriverText("DriverCockpit_LiveRoute_Recenter")) { fitTrigger += 1 }
                iconButton("location.fill", label: ppDriverText("DriverCockpit_LiveRoute_MyLoc")) { locationTrigger += 1 }
                    .disabled(tracker.usableLocation == nil)
                    .opacity(tracker.usableLocation == nil ? 0.45 : 1)
            }
            .padding(12)
            if mapFailed {
                VStack(spacing: 10) {
                    Image(systemName: "map").font(.title2)
                    Text(ppDriverText("ProRoute_MapUnavailable")).font(AdminType.bodyBold)
                    Text(ppDriverText("ProRoute_MapUnavailableBody")).font(AdminType.footnote)
                    Button {
                        mapFailed = false; mapRevision += 1
                    } label: {
                        Text(ppDriverText("DriverCockpit_LiveRoute_Retry"))
                            .font(AdminType.calloutBold).frame(minHeight: 44)
                    }
                }
                .multilineTextAlignment(.center)
                .padding(20)
                .background(AdminSurface.card, in: RoundedRectangle(cornerRadius: 20))
                .frame(maxWidth: 300)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(20)
            }
        }
    }

    private var destinationDock: some View {
        VStack(alignment: .leading, spacing: 14) {
            stopSelector
            
            if selectedStop == .storeToCustomer {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "#2563EB"))
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ppDriverText("DriverCockpit_LiveRoute_PickupStop"))
                                .font(AdminType.caption2Bold)
                                .foregroundStyle(Color(hex: "#2563EB"))
                            Text(pickupAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : pickupAddress.primary)
                                .font(AdminType.footnoteBold)
                                .foregroundStyle(AdminSurface.primaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AdminSurface.secondaryText)
                            .padding(.leading, 6)
                        Text(ppDriverText("ProRoute_FromStoreToCustomer"))
                            .font(AdminType.caption2)
                            .foregroundStyle(AdminSurface.secondaryText)
                    }
                    HStack(alignment: .center, spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(hex: "#E11D48"))
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(ppDriverText("DriverCockpit_LiveRoute_DropoffStop"))
                                .font(AdminType.caption2Bold)
                                .foregroundStyle(Color(hex: "#E11D48"))
                            Text(dropoffAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : dropoffAddress.primary)
                                .font(AdminType.footnoteBold)
                                .foregroundStyle(AdminSurface.primaryText)
                                .lineLimit(2)
                        }
                        Spacer()
                        iconButton(copied ? "checkmark" : "doc.on.doc",
                                   label: ppDriverText(copied ? "ProRoute_Copied" : "DriverCockpit_LiveRoute_CopyCoordinates")) {
                            copyCoordinates()
                        }
                    }
                }
                .padding(12)
                .background(AdminSurface.backgroundSecondary, in: RoundedRectangle(cornerRadius: 14))
            } else {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: selectedStop == .pickup ? "storefront" : "mappin.and.ellipse")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(AdminSurface.primary)
                        .frame(width: 30, height: 36)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(activeAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : activeAddress.primary)
                            .font(AdminType.title3Bold)
                            .foregroundStyle(AdminSurface.primaryText)
                            .fixedSize(horizontal: false, vertical: true)
                        if !activeAddress.secondary.isEmpty && activeAddress.secondary != activeAddress.primary {
                            Text(activeAddress.secondary)
                                .font(AdminType.footnote)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    iconButton(copied ? "checkmark" : "doc.on.doc",
                               label: ppDriverText(copied ? "ProRoute_Copied" : "DriverCockpit_LiveRoute_CopyCoordinates")) {
                        copyCoordinates()
                    }
                    .disabled(activeCoordinate == nil)
                    .opacity(activeCoordinate == nil ? 0.45 : 1)
                }
            }

            // Dedicated button to review route from store to customer
            if selectedStop != .storeToCustomer {
                Button {
                    selectedStop = .storeToCustomer
                    showsReview = true
                } label: {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle()
                                .fill(AdminSurface.primary.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(AdminSurface.primary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(ppDriverText("ProRoute_ReviewStoreToCustomer"))
                                .font(AdminType.calloutBold)
                                .foregroundStyle(AdminSurface.primaryText)
                            Text(ppDriverText("ProRoute_ReviewStoreToCustomerSubtitle"))
                                .font(AdminType.caption2)
                                .foregroundStyle(AdminSurface.secondaryText)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: isArabic ? "chevron.left" : "chevron.right")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AdminSurface.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AdminSurface.backgroundSecondary, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(AdminSurface.primary.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(ppDriverText("ProRoute_ReviewStoreToCustomer"))
            }

            if let routeInfo = visibleRouteInfo { metrics(routeInfo) } else { routeStatus }
            if handoffFailed {
                Text(ppDriverText("ProRoute_MapsOpenFailed"))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.crimson)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) { reviewButton; startButton }
                VStack(spacing: 10) { startButton; reviewButton }
            }
            Text(ppDriverText("ProRoute_VoiceNavigationHint"))
                .font(AdminType.caption1)
                .foregroundStyle(AdminSurface.secondaryText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var stopSelector: some View {
        HStack(spacing: 4) {
            stopButton(.pickup, key: "DriverCockpit_LiveRoute_PickupStop", symbol: "storefront")
            stopButton(.dropoff, key: "DriverCockpit_LiveRoute_DropoffStop", symbol: "mappin")
            stopButton(.storeToCustomer, key: "ProRoute_StoreToCustomer", symbol: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .padding(4)
        .background(AdminSurface.backgroundSecondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func stopButton(_ stop: PPDeliveryRouteStop, key: String, symbol: String) -> some View {
        Button {
            guard selectedStop != stop else { return }
            selectedStop = stop
            routeInfo = nil; routeRevision += 1
            copied = false; handoffFailed = false
        } label: {
            Label(ppDriverText(key), systemImage: symbol)
                .font(AdminType.footnoteBold)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .foregroundStyle(selectedStop == stop ? AdminSurface.primary : AdminSurface.secondaryText)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 4)
                .background(selectedStop == stop ? AdminSurface.card : Color.clear,
                            in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedStop == stop ? .isSelected : [])
    }

    private func metrics(_ info: PPRouteInfo) -> some View {
        HStack(spacing: 20) {
            metric(info.durationFormatted, label: "ProRoute_DriveTime", symbol: "clock")
            Rectangle().fill(AdminSurface.hairline).frame(width: 1, height: 30)
            metric(info.distanceFormatted, label: "ProRoute_RoadDistance", symbol: "point.topleft.down.to.point.bottomright.curvepath")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 2)
    }

    private func metric(_ value: String, label: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(value, systemImage: symbol).font(AdminType.headlineBold)
                .foregroundStyle(AdminSurface.primaryText)
            Text(ppDriverText(label)).font(AdminType.caption1).foregroundStyle(AdminSurface.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var reviewButton: some View {
        Button { showsReview = true } label: {
            Label(ppDriverText("ProRoute_Review"), systemImage: "list.bullet")
                .font(AdminType.calloutBold)
                .foregroundStyle(AdminSurface.primary)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 14)
                .background(AdminSurface.backgroundSecondary, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .accessibilityFocused($reviewFocused)
    }

    private var startButton: some View {
        Button { openMaps(startNavigation: true) } label: {
            HStack(spacing: 8) {
                if openingMaps { ProgressView().tint(.white) } else { Image(systemName: "location.north.fill") }
                Text(ppDriverText("ProRoute_Start"))
            }
            .font(AdminType.calloutBold)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, 14)
            .background(canOpenDestination ? AdminSurface.primary : AdminSurface.secondaryText,
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .disabled(!canOpenDestination || openingMaps)
    }

    @ViewBuilder private var routeStatus: some View {
        switch phase {
        case .loading, .locating:
            HStack(spacing: 10) {
                ProgressView().tint(AdminSurface.primary)
                Text(ppDriverText(isLoadingDirections ? "DriverCockpit_LiveRoute_Calculating" : "ProRoute_Locating"))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
            }.frame(minHeight: 32)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Label(ppDriverText(statusTitleKey), systemImage: "exclamationmark.circle")
                    .font(AdminType.footnoteBold).foregroundStyle(AdminSurface.primaryText)
                Text(ppDriverText(statusBodyKey)).font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                HStack(spacing: 20) {
                    Button(action: retry) {
                        Text(ppDriverText("DriverCockpit_LiveRoute_Retry")).frame(minHeight: 44)
                    }
                    if case .locationDenied = phase {
                        Button(action: openLocationSettings) {
                            Text(ppDriverText("ProRoute_LocationSettings")).frame(minHeight: 44)
                        }
                    }
                }.font(AdminType.footnoteBold).foregroundStyle(AdminSurface.primary).frame(minHeight: 44)
            }
        }
    }

    private var isLoadingDirections: Bool { if case .loading = phase { return true }; return false }
    private var statusTitleKey: String {
        switch phase {
        case .addressUnavailable: return "ProRoute_AddressUnavailable"
        case .locationDenied: return "ProRoute_LocationDenied"
        case .locationUnavailable: return "ProRoute_LocationUnavailable"
        case .failed(.noDrivingRoute): return "ProRoute_NoDrivingRoute"
        default: return "DriverCockpit_LiveRoute_Failed"
        }
    }
    private var statusBodyKey: String {
        switch phase {
        case .addressUnavailable: return "ProRoute_AddressUnavailableBody"
        case .locationDenied: return "ProRoute_LocationDeniedBody"
        case .locationUnavailable: return "ProRoute_LocationUnavailableBody"
        case .failed(.noDrivingRoute): return "ProRoute_NoDrivingRouteBody"
        default: return "ProRoute_DirectionsUnavailableBody"
        }
    }

    private var routeReview: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedStop == .storeToCustomer {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "storefront.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#2563EB"))
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ppDriverText("DriverCockpit_LiveRoute_PickupStop"))
                                        .font(AdminType.caption2Bold)
                                        .foregroundStyle(Color(hex: "#2563EB"))
                                    Text(pickupAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : pickupAddress.primary)
                                        .font(AdminType.bodyBold)
                                        .foregroundStyle(AdminSurface.primaryText)
                                }
                                Spacer()
                            }
                            HStack(spacing: 8) {
                                Image(systemName: "arrow.down")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AdminSurface.secondaryText)
                                    .padding(.leading, 6)
                                Text(ppDriverText("ProRoute_FromStoreToCustomer"))
                                    .font(AdminType.caption2)
                                    .foregroundStyle(AdminSurface.secondaryText)
                            }
                            HStack(alignment: .center, spacing: 10) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#E11D48"))
                                    .frame(width: 24, height: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ppDriverText("DriverCockpit_LiveRoute_DropoffStop"))
                                        .font(AdminType.caption2Bold)
                                        .foregroundStyle(Color(hex: "#E11D48"))
                                    Text(dropoffAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : dropoffAddress.primary)
                                        .font(AdminType.bodyBold)
                                        .foregroundStyle(AdminSurface.primaryText)
                                }
                                Spacer()
                            }
                        }
                        .padding(14)
                        .background(AdminSurface.card, in: RoundedRectangle(cornerRadius: 14))
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(ppDriverText(selectedStop == .pickup ? "DriverCockpit_LiveRoute_PickupStop" : "DriverCockpit_LiveRoute_DropoffStop"))
                                .font(AdminType.footnoteBold).foregroundStyle(AdminSurface.primary)
                            Text(activeAddress.primary.isEmpty ? ppDriverText("DriverCockpit_Address_Pending") : activeAddress.primary)
                                .font(AdminType.title2).foregroundStyle(AdminSurface.primaryText)
                            if !activeAddress.secondary.isEmpty {
                                Text(activeAddress.secondary).font(AdminType.body).foregroundStyle(AdminSurface.secondaryText)
                            }
                        }
                    }
                    if let info = visibleRouteInfo {
                        metrics(info)
                        Text(ppDriverText(selectedStop == .storeToCustomer ? "ProRoute_ReviewStoreHint" : "ProRoute_ReviewHint"))
                            .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
                        if info.steps.isEmpty {
                            Text(ppDriverText("ProRoute_StepsUnavailable")).font(AdminType.body)
                        } else {
                            LazyVStack(alignment: .leading, spacing: 0) {
                                ForEach(info.steps) { step in
                                    Button {
                                        pendingStep = step
                                        pendingStepRequestID = loadedRequestID
                                        showsReview = false
                                    } label: { stepRow(step) }
                                    .buttonStyle(.plain)
                                    .accessibilityHint(ppDriverText("ProRoute_FocusStep"))
                                    if step.id != info.steps.last?.id { Divider().padding(.leading, 48) }
                                }
                            }
                        }
                    } else { routeStatus }
                    Button { openMaps(startNavigation: false) } label: {
                        Label(ppDriverText("ProRoute_OpenMapsReview"), systemImage: "arrow.up.forward.app")
                            .font(AdminType.calloutBold).frame(minHeight: 48)
                    }
                    .foregroundStyle(AdminSurface.primary)
                    .disabled(!canOpenDestination || openingMaps)
                    if handoffFailed {
                        Text(ppDriverText("ProRoute_MapsOpenFailed")).font(AdminType.footnote).foregroundStyle(AdminSurface.crimson)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .background(AdminSurface.background)
            .navigationTitle(ppDriverText(selectedStop == .storeToCustomer ? "ProRoute_ReviewStoreToCustomer" : "ProRoute_Review"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showsReview = false } label: {
                        Text(ppDriverText("DriverCockpit_LiveRoute_Close"))
                            .font(AdminType.calloutBold).frame(minHeight: 44)
                    }
                }
            }
        }
        .tint(AdminSurface.primary)
        .environment(\.layoutDirection, isArabic ? .rightToLeft : .leftToRight)
        .environment(\.locale, Locale(identifier: Language.currentLanguageCode()))
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func stepRow(_ step: PPRouteStep) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: step.maneuver.sfSymbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(AdminSurface.primary)
                .frame(width: 36, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(step.instructions).font(AdminType.bodyBold).foregroundStyle(AdminSurface.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text([step.distanceText, step.durationText].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(AdminType.footnote).foregroundStyle(AdminSurface.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ppDriverFormat("ProRoute_StepAccessibility", step.stepNumber, step.instructions, step.distanceText))
    }

    private func finishReview() {
        if let step = pendingStep, pendingStepRequestID == routeRequestID,
           visibleRouteInfo?.steps.contains(where: { $0.id == step.id }) == true {
            focusedCoordinate = step.startCoordinate
            focusTrigger += 1
            UIAccessibility.post(notification: .announcement, argument: ppDriverText("ProRoute_StepFocused"))
        }
        pendingStep = nil
        pendingStepRequestID = nil
        reviewFocused = true
    }

    private func iconButton(_ symbol: String, label: String, action: @escaping @MainActor () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AdminSurface.primaryText)
                .frame(width: 44, height: 44)
                .background(AdminSurface.card, in: Circle())
                .contentShape(Circle())
        }.buttonStyle(.plain).accessibilityLabel(label)
    }

    private func loadSelectedRoute() async {
        let requestID = routeRequestID
        let stop = selectedStop
        routeInfo = nil; routeRevision += 1
        phase = .locating
        guard scenePhase == .active else { return }

        if stop == .storeToCustomer {
            let pQuery = [pickupAddress.mapQuery, pickupAddress.secondary, pickupAddress.primary]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
            let dQuery = [dropoffAddress.mapQuery, dropoffAddress.secondary, dropoffAddress.primary]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty } ?? ""
            guard !pQuery.isEmpty && !dQuery.isEmpty else {
                phase = .addressUnavailable
                return
            }

            var pCoord = pickupCoordinate
            if pCoord == nil {
                pCoord = await PPGoogleMapsRouteService.shared.resolveCoordinate(address: pQuery)
                if let pCoord {
                    pickupCoordinate = pCoord
                    pickupResolvedQuery = pickupAddress.mapQuery
                }
            }

            var dCoord = dropoffCoordinate
            if dCoord == nil {
                dCoord = await PPGoogleMapsRouteService.shared.resolveCoordinate(address: dQuery)
                if let dCoord {
                    dropoffCoordinate = dCoord
                    dropoffResolvedQuery = dropoffAddress.mapQuery
                }
            }

            guard !Task.isCancelled, requestID == routeRequestID else { return }
            guard let origin = pCoord, let destination = dCoord else {
                phase = .addressUnavailable
                return
            }

            phase = .loading
            do {
                let info = try await PPGoogleMapsRouteService.shared.fetchRoute(
                    origin: origin, destination: destination, isArabic: isArabic)
                guard !Task.isCancelled, requestID == routeRequestID else { return }
                routeInfo = info
                loadedRequestID = requestID
                routeRevision += 1
                phase = .ready
                fitTrigger += 1
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled, requestID == routeRequestID else { return }
                phase = .failed(error as? PPRouteServiceError ?? .serviceUnavailable)
            }
            return
        }

        let query = activeAddress.mapQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        // No primary/area-summary fallback: hidden or missing exact destinations stay hidden.
        guard !query.isEmpty else { phase = .addressUnavailable; return }
        var coordinate = activeCoordinate
        if coordinate == nil { coordinate = await PPGoogleMapsRouteService.shared.resolveCoordinate(address: query) }
        guard !Task.isCancelled, requestID == routeRequestID else { return }
        guard let coordinate else { phase = .addressUnavailable; return }
        if stop == .pickup {
            pickupCoordinate = coordinate; pickupResolvedQuery = pickupAddress.mapQuery
        } else {
            dropoffCoordinate = coordinate; dropoffResolvedQuery = dropoffAddress.mapQuery
        }
        if tracker.authorizationStatus == .denied || tracker.authorizationStatus == .restricted {
            phase = .locationDenied
            return
        }
        guard let origin = tracker.usableLocation else {
            do { try await Task.sleep(for: .seconds(15)) } catch { return }
            guard !Task.isCancelled, requestID == routeRequestID else { return }
            phase = .locationUnavailable
            return
        }
        phase = .loading
        do {
            let info = try await PPGoogleMapsRouteService.shared.fetchRoute(
                origin: origin.coordinate, destination: coordinate, isArabic: isArabic)
            guard !Task.isCancelled, requestID == routeRequestID else { return }
            routeInfo = info; loadedRequestID = requestID; routeRevision += 1
            phase = .ready
            fitTrigger += 1
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, requestID == routeRequestID else { return }
            phase = .failed(error as? PPRouteServiceError ?? .serviceUnavailable)
        }
    }

    private func retry() {
        tracker.stopTracking(); tracker.startTracking()
        retryRevision += 1
    }

    private func copyCoordinates() {
        if selectedStop == .storeToCustomer {
            var parts: [String] = []
            if let p = pickupCoordinate {
                parts.append("Store: \(String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), p.latitude, p.longitude))")
            }
            if let d = dropoffCoordinate {
                parts.append("Customer: \(String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"), d.latitude, d.longitude))")
            }
            if !parts.isEmpty {
                UIPasteboard.general.string = parts.joined(separator: "\n")
                copied = true; copyRevision += 1
                UIAccessibility.post(notification: .announcement, argument: ppDriverText("ProRoute_Copied"))
            }
            return
        }
        guard canOpenDestination, let coordinate = activeCoordinate else { return }
        UIPasteboard.general.string = String(format: "%.6f,%.6f", locale: Locale(identifier: "en_US_POSIX"),
                                            coordinate.latitude, coordinate.longitude)
        copied = true; copyRevision += 1
        UIAccessibility.post(notification: .announcement, argument: ppDriverText("ProRoute_Copied"))
    }

    private func openLocationSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func openMaps(startNavigation: Bool) {
        guard canOpenDestination, !openingMaps else { return }
        openingMaps = true; handoffFailed = false

        let destQuery: String
        let originQuery: String?
        if selectedStop == .storeToCustomer {
            destQuery = dropoffCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? dropoffAddress.mapQuery
            originQuery = pickupCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? pickupAddress.mapQuery
        } else {
            destQuery = activeCoordinate.map { "\($0.latitude),\($0.longitude)" } ?? activeAddress.mapQuery
            originQuery = nil
        }

        Task { @MainActor in
            var google = URLComponents(string: "comgooglemaps://")!
            var gItems = [
                URLQueryItem(name: "daddr", value: destQuery),
                URLQueryItem(name: "directionsmode", value: "driving")
            ]
            if let originQuery, !originQuery.isEmpty {
                gItems.append(URLQueryItem(name: "saddr", value: originQuery))
            }
            google.queryItems = gItems

            if startNavigation, let url = google.url, UIApplication.shared.canOpenURL(url),
               await UIApplication.shared.open(url, options: [:]) {
                openingMaps = false
                return
            }

            var fallback = URLComponents(string: startNavigation ? "https://maps.apple.com/" : "https://www.google.com/maps/dir/")!
            var fbItems: [URLQueryItem] = []
            if startNavigation {
                fbItems.append(URLQueryItem(name: "daddr", value: destQuery))
                fbItems.append(URLQueryItem(name: "dirflg", value: "d"))
                if let originQuery, !originQuery.isEmpty {
                    fbItems.append(URLQueryItem(name: "saddr", value: originQuery))
                }
            } else {
                fbItems.append(URLQueryItem(name: "api", value: "1"))
                if let originQuery, !originQuery.isEmpty {
                    fbItems.append(URLQueryItem(name: "origin", value: originQuery))
                }
                fbItems.append(URLQueryItem(name: "destination", value: destQuery))
                fbItems.append(URLQueryItem(name: "travelmode", value: "driving"))
            }
            fallback.queryItems = fbItems

            let opened: Bool
            if let url = fallback.url { opened = await UIApplication.shared.open(url, options: [:]) } else { opened = false }
            openingMaps = false; handoffFailed = !opened
        }
    }

    private func styleLabel(_ style: PPMapStyleType) -> String {
        ppDriverText(style == .roadmap ? "DriverCockpit_LiveRoute_MapNormal" :
                     style == .hybrid ? "DriverCockpit_LiveRoute_MapSatellite" : "DriverCockpit_LiveRoute_MapTerrain")
    }
}
