//
//  PPMarketplaceBranchLocationPicker.swift
//  PurePetsPro
//
//  NextGen V10 Category-Defining Spatial Location & Delivery Pickup Surface for Pro App.
//  Bridges provider branch operations with Pure Pets Infra delivery pickup normalization:
//  - Interactive 60/120fps MapKit camera with physics-based living center beacon and radar pulse.
//  - Real-time debounced reverse geocoding (CLGeocoder) with bilingual street & district resolution.
//  - Live coordinate telemetry HUD with 6-decimal-place monospace precision and 1-tap copy.
//  - Instant Qatar Commercial Logistics Hub quick-teleport chips.
//  - Smart MKLocalSearch bar with instant place and street autocompletion.
//  - Verified Courier Pickup & Routing Reassurance contract for fulfillment dispatches.
//  - Full bidirectional Arabic RTL / English LTR support with Beiruti typography & haptic physics.
//

import SwiftUI
@preconcurrency import MapKit
import CoreLocation

// MARK: - Qatar Logistics Hub Presets

public struct PPProQatarHubPreset: Identifiable, Hashable, @unchecked Sendable {
    public let id: String
    public let nameAr: String
    public let nameEn: String
    public let coordinate: CLLocationCoordinate2D
    public let icon: String

    public init(id: String, nameAr: String, nameEn: String, coordinate: CLLocationCoordinate2D, icon: String = "building.2.fill") {
        self.id = id
        self.nameAr = nameAr
        self.nameEn = nameEn
        self.coordinate = coordinate
        self.icon = icon
    }

    public var localizedName: String {
        Language.isRTL() ? nameAr : nameEn
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: PPProQatarHubPreset, rhs: PPProQatarHubPreset) -> Bool {
        lhs.id == rhs.id
    }

    @MainActor public static let standardHubs: [PPProQatarHubPreset] = [
        PPProQatarHubPreset(
            id: "doha_salwa",
            nameAr: "طريق سلوى - المتجر الرئيسي",
            nameEn: "Salwa Road - Flagship",
            coordinate: CLLocationCoordinate2D(latitude: 25.2605, longitude: 51.4880),
            icon: "star.fill"
        ),
        PPProQatarHubPreset(
            id: "pearl_porto",
            nameAr: "اللؤلؤة - بورتو أرابيا",
            nameEn: "The Pearl - Porto Arabia",
            coordinate: CLLocationCoordinate2D(latitude: 25.3713, longitude: 51.5499),
            icon: "water.waves"
        ),
        PPProQatarHubPreset(
            id: "lusail_marina",
            nameAr: "لوسيل - المارينا والبروميناد",
            nameEn: "Lusail - Marina Promenade",
            coordinate: CLLocationCoordinate2D(latitude: 25.4208, longitude: 51.5284),
            icon: "building.columns.fill"
        ),
        PPProQatarHubPreset(
            id: "al_rayyan",
            nameAr: "الريان - شارع الوعب",
            nameEn: "Al Rayyan - Al Waab",
            coordinate: CLLocationCoordinate2D(latitude: 25.2750, longitude: 51.4420),
            icon: "tram.fill"
        ),
        PPProQatarHubPreset(
            id: "al_sadd",
            nameAr: "السد - سحيم بن حمد",
            nameEn: "Al Sadd - Suhaim Bin Hamad",
            coordinate: CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.4988),
            icon: "building.2.crop.circle"
        ),
        PPProQatarHubPreset(
            id: "al_wakrah",
            nameAr: "الوكرة - السوق القديم",
            nameEn: "Al Wakrah - Souq & Coast",
            coordinate: CLLocationCoordinate2D(latitude: 25.1768, longitude: 51.6035),
            icon: "sailboat.fill"
        ),
        PPProQatarHubPreset(
            id: "west_bay",
            nameAr: "الخليج الغربي - الدفنة",
            nameEn: "West Bay - Al Dafna",
            coordinate: CLLocationCoordinate2D(latitude: 25.3210, longitude: 51.5310),
            icon: "building.fill"
        )
    ]
}

// MARK: - Location Picker ViewModel

@MainActor
public final class PPMarketplaceBranchLocationPickerViewModel: NSObject, ObservableObject {
    @Published public var currentCoordinate: CLLocationCoordinate2D
    @Published public var formattedAddress: String = ""
    @Published public var isGeocoding: Bool = false
    @Published public var isDragging: Bool = false
    @Published public var mapType: MKMapType = .standard
    @Published public var searchQuery: String = ""
    @Published public var searchResults: [MKLocalSearchCompletion] = []
    @Published public var isSearching: Bool = false
    @Published public var toastMessage: String? = nil

    private let geocoder = CLGeocoder()
    private var geocodeWorkItem: DispatchWorkItem?
    private var searchCompleter = MKLocalSearchCompleter()
    private var searchCompleterAdapter: PPProSearchCompleterAdapter?
    public weak var mapView: MKMapView?

    public init(initialCoordinate: CLLocationCoordinate2D?, initialAddress: String?) {
        let fallback = CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310)
        let resolved = initialCoordinate.flatMap {
            (abs($0.latitude) > 0.001 && abs($0.longitude) > 0.001) ? $0 : nil
        } ?? fallback

        self.currentCoordinate = resolved
        self.formattedAddress = initialAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        super.init()

        let adapter = PPProSearchCompleterAdapter(viewModel: self)
        self.searchCompleterAdapter = adapter
        searchCompleter.delegate = adapter
        searchCompleter.resultTypes = [.address, .pointOfInterest]
        let qatarCenter = CLLocationCoordinate2D(latitude: 25.2854, longitude: 51.5310)
        searchCompleter.region = MKCoordinateRegion(
            center: qatarCenter,
            span: MKCoordinateSpan(latitudeDelta: 1.2, longitudeDelta: 1.2)
        )

        if self.formattedAddress.isEmpty {
            performReverseGeocode(for: resolved)
        }
    }

    public func updateCenterCoordinate(_ coordinate: CLLocationCoordinate2D) {
        self.currentCoordinate = coordinate
        scheduleReverseGeocode(for: coordinate)
    }

    public func setDragging(_ dragging: Bool) {
        if self.isDragging != dragging {
            self.isDragging = dragging
            if !dragging {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        }
    }

    public func scheduleReverseGeocode(for coordinate: CLLocationCoordinate2D) {
        geocodeWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.performReverseGeocode(for: coordinate)
        }
        geocodeWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: item)
    }

    private func performReverseGeocode(for coordinate: CLLocationCoordinate2D) {
        isGeocoding = true
        let loc = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let preferredLocale = Locale(identifier: Language.isRTL() ? "ar_QA" : "en_QA")

        geocoder.reverseGeocodeLocation(loc, preferredLocale: preferredLocale) { [weak self] placemarks, error in
            Task { @MainActor in
                guard let self else { return }
                self.isGeocoding = false
                if let pm = placemarks?.first {
                    var parts: [String] = []
                    if let name = pm.name, !name.isEmpty { parts.append(name) }
                    if let thoroughfare = pm.thoroughfare, !thoroughfare.isEmpty, !parts.contains(thoroughfare) {
                        parts.append(thoroughfare)
                    }
                    if let subLocality = pm.subLocality, !subLocality.isEmpty, !parts.contains(subLocality) {
                        parts.append(subLocality)
                    }
                    if let locality = pm.locality, !locality.isEmpty, !parts.contains(locality) {
                        parts.append(locality)
                    }
                    if let country = pm.country, !country.isEmpty, !parts.contains(country) {
                        parts.append(country)
                    }

                    if !parts.isEmpty {
                        self.formattedAddress = parts.joined(separator: " · ")
                    } else {
                        self.formattedAddress = String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
                    }
                }
            }
        }
    }

    public func moveToHub(_ hub: PPProQatarHubPreset) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        self.currentCoordinate = hub.coordinate
        let region = MKCoordinateRegion(
            center: hub.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
        )
        mapView?.setRegion(region, animated: true)
        scheduleReverseGeocode(for: hub.coordinate)
    }

    public func updateSearchQuery(_ query: String) {
        self.searchQuery = query
        if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            self.searchResults = []
            self.isSearching = false
            searchCompleter.queryFragment = ""
        } else {
            self.isSearching = true
            searchCompleter.queryFragment = query
        }
    }

    public func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            Task { @MainActor in
                guard let self, let item = response?.mapItems.first else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()

                let coord = item.placemark.coordinate
                self.currentCoordinate = coord
                self.searchQuery = ""
                self.searchResults = []
                self.isSearching = false

                let region = MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.008, longitudeDelta: 0.008)
                )
                self.mapView?.setRegion(region, animated: true)
                self.scheduleReverseGeocode(for: coord)
            }
        }
    }

    public func toggleMapType() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.easeOut(duration: 0.2)) {
            self.mapType = (self.mapType == .standard) ? .hybrid : .standard
        }
    }

    public func copyCoordinates() {
        let str = String(format: "%.6f, %.6f", currentCoordinate.latitude, currentCoordinate.longitude)
        UIPasteboard.general.string = str
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        showToast(Language.get("MarketplaceBranches_CoordsCopied", alter: "تم نسخ الإحداثيات بدقة") ?? "تم نسخ الإحداثيات بدقة")
    }

    public func showToast(_ msg: String) {
        self.toastMessage = msg
        Task {
            try? await Task.sleep(nanoseconds: 2_400_000_000)
            if self.toastMessage == msg {
                self.toastMessage = nil
            }
        }
    }
}

// MARK: - Search Completer Adapter (Swift 6 Safe)

private final class PPProSearchCompleterAdapter: NSObject, MKLocalSearchCompleterDelegate, @unchecked Sendable {
    private weak var viewModel: PPMarketplaceBranchLocationPickerViewModel?

    init(viewModel: PPMarketplaceBranchLocationPickerViewModel) {
        self.viewModel = viewModel
        super.init()
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        Task { @MainActor [weak viewModel] in
            viewModel?.searchResults = results
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor [weak viewModel] in
            viewModel?.searchResults = []
        }
    }
}

// MARK: - Interactive MapView Representable

public struct PPMarketplaceBranchInteractiveMapView: UIViewRepresentable {
    @ObservedObject var viewModel: PPMarketplaceBranchLocationPickerViewModel

    public func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel)
    }

    public func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.showsCompass = true
        mapView.showsScale = true
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.mapType = viewModel.mapType

        let region = MKCoordinateRegion(
            center: viewModel.currentCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.012, longitudeDelta: 0.012)
        )
        mapView.setRegion(region, animated: false)

        viewModel.mapView = mapView
        return mapView
    }

    public func updateUIView(_ uiView: MKMapView, context: Context) {
        if uiView.mapType != viewModel.mapType {
            uiView.mapType = viewModel.mapType
        }
    }

    public final class Coordinator: NSObject, MKMapViewDelegate {
        let viewModel: PPMarketplaceBranchLocationPickerViewModel

        init(viewModel: PPMarketplaceBranchLocationPickerViewModel) {
            self.viewModel = viewModel
        }

        public func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            Task { @MainActor in
                self.viewModel.setDragging(true)
            }
        }

        public func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let center = mapView.centerCoordinate
            Task { @MainActor in
                self.viewModel.setDragging(false)
                self.viewModel.updateCenterCoordinate(center)
            }
        }
    }
}

// MARK: - Sovereign NextGen V10 Location Picker Surface

public struct PPMarketplaceBranchLocationPicker: View {
    let branchName: String?
    let initialCoordinate: CLLocationCoordinate2D?
    let initialAddress: String?
    let onConfirm: @MainActor (CLLocationCoordinate2D, String) -> Void
    let onDismiss: @MainActor () -> Void

    @StateObject private var viewModel: PPMarketplaceBranchLocationPickerViewModel
    @State private var radarPulse: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        branchName: String?,
        initialCoordinate: CLLocationCoordinate2D?,
        initialAddress: String?,
        onConfirm: @escaping @MainActor (CLLocationCoordinate2D, String) -> Void,
        onDismiss: @escaping @MainActor () -> Void
    ) {
        self.branchName = branchName
        self.initialCoordinate = initialCoordinate
        self.initialAddress = initialAddress
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        _viewModel = StateObject(wrappedValue: PPMarketplaceBranchLocationPickerViewModel(
            initialCoordinate: initialCoordinate,
            initialAddress: initialAddress
        ))
    }

    public var body: some View {
        ZStack {
            // Level 0: 60/120fps Map Canvas
            PPMarketplaceBranchInteractiveMapView(viewModel: viewModel)
                .ignoresSafeArea()

            // Level 1: Precise Living Center Beacon Pin & Animated Radar Pulse
            centerBeaconOverlay

            // Level 2: Top Floating Spatial Search Island & Layer Toggles
            VStack(spacing: 0) {
                topSpatialIsland
                if viewModel.isSearching && !viewModel.searchResults.isEmpty {
                    searchResultsDropdown
                }
                Spacer()
            }
            .padding(.top, 8)
            .padding(.horizontal, 18)

            // Level 3: Bottom Tactical Pickup Intelligence & Reassurance Dock
            VStack(spacing: 0) {
                Spacer()
                bottomTacticalDock
            }
            .ignoresSafeArea(edges: .bottom)

            // Level 4: Telemetry Toast Banner
            if let toast = viewModel.toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(toast)
                            .font(PPBeirutiFont.bold(13, relativeTo: .footnote))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(Color.green.opacity(0.3), lineWidth: 1))
                    .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
                    .padding(.bottom, 220)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.toastMessage)
                .zIndex(90)
            }
        }
        .environment(\.layoutDirection, Language.isRTL() ? .rightToLeft : .leftToRight)
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: false)) {
                    radarPulse = true
                }
            }
        }
    }

    // MARK: - Center Living Beacon Pin

    private var centerBeaconOverlay: some View {
        ZStack {
            // Radar pulse wave
            Circle()
                .stroke(Color(uiColor: .ppPrimary).opacity(radarPulse ? 0.0 : 0.45), lineWidth: 2)
                .frame(width: radarPulse ? 100 : 20, height: radarPulse ? 100 : 20)
                .scaleEffect(radarPulse ? 1.0 : 0.3)
                .opacity(viewModel.isDragging ? 0.2 : 1.0)

            // Ground shadow
            Ellipse()
                .fill(Color.black.opacity(viewModel.isDragging ? 0.18 : 0.32))
                .frame(
                    width: viewModel.isDragging ? 18 : 26,
                    height: viewModel.isDragging ? 7 : 10
                )
                .offset(y: 22)
                .blur(radius: viewModel.isDragging ? 3 : 1.5)

            // Living Spatial Beacon Pin
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimaryDarker)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(uiColor: .ppPrimary).opacity(0.4), radius: 8, y: 4)

                    Image(systemName: "box.truck.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }

                // Needle tip
                PPLocationNeedleTriangle()
                    .fill(Color(uiColor: .ppPrimary))
                    .frame(width: 14, height: 10)
                    .offset(y: -2)
            }
            .offset(y: viewModel.isDragging ? -32 : -18)
            .animation(.spring(response: 0.28, dampingFraction: 0.65), value: viewModel.isDragging)
        }
        .allowsHitTesting(false)
    }

    // MARK: - Top Spatial Island

    private var topSpatialIsland: some View {
        HStack(spacing: 10) {
            // Close Button
            Button(action: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onDismiss()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppTextPrimary))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
            }
            .ppTactile()

            // Search Bar Field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(Color(uiColor: .ppPrimary))

                TextField(Language.get("MarketplaceBranches_SearchLocation", alter: "ابحث عن موقع أو شارع أو معلم في قطر…") ?? "ابحث عن موقع أو شارع أو معلم في قطر…", text: Binding(
                    get: { viewModel.searchQuery },
                    set: { viewModel.updateSearchQuery($0) }
                ))
                .font(PPBeirutiFont.medium(14, relativeTo: .body))
                .foregroundColor(Color(uiColor: .ppTextPrimary))
                .disableAutocorrection(true)

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.updateSearchQuery("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 0.8))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)

            // Map Style Toggle
            Button(action: {
                viewModel.toggleMapType()
            }) {
                Image(systemName: viewModel.mapType == .standard ? "globe.europe.africa.fill" : "map.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(uiColor: .ppPrimary))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 0.8))
                    .shadow(color: .black.opacity(0.10), radius: 6, y: 2)
            }
            .ppTactile()
        }
    }

    // MARK: - Search Results Dropdown

    private var searchResultsDropdown: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(viewModel.searchResults, id: \.self) { result in
                        Button(action: {
                            viewModel.selectSearchResult(result)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(Color(uiColor: .ppPrimary))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(PPBeirutiFont.bold(14, relativeTo: .body))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                                        .lineLimit(1)

                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(PPBeirutiFont.regular(12, relativeTo: .caption))
                                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                                            .lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider().padding(.horizontal, 16)
                    }
                }
            }
            .frame(maxHeight: 240)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 0.8))
        .shadow(color: .black.opacity(0.15), radius: 12, y: 6)
        .padding(.top, 8)
    }

    // MARK: - Bottom Tactical Dock

    private var bottomTacticalDock: some View {
        VStack(spacing: 0) {
            // Quick Hubs Teleport Carousel
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppPrimary))

                    Text(Language.get("MarketplaceBranches_QuickHubs", alter: "المراكز اللوجستية الكبرى في قطر") ?? "المراكز اللوجستية الكبرى في قطر")
                        .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                        .foregroundColor(Color(uiColor: .ppTextSecondary))

                    Spacer()
                }
                .padding(.horizontal, 18)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(PPProQatarHubPreset.standardHubs) { hub in
                            Button(action: {
                                viewModel.moveToHub(hub)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: hub.icon)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(Color(uiColor: .ppPrimary))

                                    Text(hub.localizedName)
                                        .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                                        .foregroundColor(Color(uiColor: .ppTextPrimary))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(uiColor: .ppSurface).opacity(0.92), in: Capsule())
                                .overlay(Capsule().stroke(Color(uiColor: .ppBorder).opacity(0.4), lineWidth: 0.8))
                            }
                            .ppTactile()
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Address & Courier Delivery Reassurance Card
            VStack(spacing: 12) {
                // Courier Guidance Banner
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.green.opacity(0.16))
                            .frame(width: 32, height: 32)
                        Image(systemName: "shippingbox.and.arrow.backward.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.green)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(Language.get("MarketplaceBranches_PickupTitle", alter: "نقطة انطلاق واستلام المناديب الرسمية") ?? "نقطة انطلاق واستلام المناديب الرسمية")
                            .font(PPBeirutiFont.bold(12, relativeTo: .caption))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))

                        Text(Language.get("MarketplaceBranches_PickupDesc", alter: "هذه الإحداثيات هي التي سيتوجه إليها مندوبو التوصيل لاستلام الشحنات من الفرع.") ?? "هذه الإحداثيات هي التي سيتوجه إليها مندوبو التوصيل لاستلام الشحنات من الفرع.")
                            .font(PPBeirutiFont.regular(10.5, relativeTo: .caption2))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                    }

                    Spacer()
                }
                .padding(10)
                .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.green.opacity(0.25), lineWidth: 0.8)
                )

                // Live Geocoded Address String
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(uiColor: .ppPrimary))

                    if viewModel.isGeocoding {
                        HStack(spacing: 8) {
                            ProgressView().scaleEffect(0.8)
                            Text(Language.get("MarketplaceBranches_ResolvingAddress", alter: "جارٍ تحديد العنوان الميداني بدقة…") ?? "جارٍ تحديد العنوان الميداني بدقة…")
                                .font(PPBeirutiFont.medium(13, relativeTo: .subheadline))
                                .foregroundColor(Color(uiColor: .ppTextSecondary))
                        }
                    } else {
                        Text(viewModel.formattedAddress.isEmpty ? (Language.get("MarketplaceBranches_SelectLocationPrompt", alter: "اسحب الخريطة لتحديد موقع الفرع بدقة") ?? "اسحب الخريطة لتحديد موقع الفرع بدقة") : viewModel.formattedAddress)
                            .font(PPBeirutiFont.bold(14, relativeTo: .body))
                            .foregroundColor(Color(uiColor: .ppTextPrimary))
                            .lineLimit(2)
                    }

                    Spacer()
                }

                // Coordinate Monospace Telemetry Strip
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: "location.north.line.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))

                        Text(String(format: "%.6f° N, %.6f° E", viewModel.currentCoordinate.latitude, viewModel.currentCoordinate.longitude))
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color(uiColor: .ppTextSecondary))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .ppSurface), in: Capsule())

                    Spacer()

                    Button(action: {
                        viewModel.copyCoordinates()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.doc")
                            Text(Language.get("Copy", alter: "نسخ") ?? "نسخ")
                        }
                        .font(PPBeirutiFont.bold(11, relativeTo: .caption2))
                        .foregroundColor(Color(uiColor: .ppPrimary))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(uiColor: .ppPrimary).opacity(0.12), in: Capsule())
                    }
                    .ppTactile()
                }

                // Primary Confirmation Action Button
                Button(action: {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                    onConfirm(viewModel.currentCoordinate, viewModel.formattedAddress)
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .bold))

                        Text(Language.get("MarketplaceBranches_ConfirmPickupPoint", alter: "اعتماد نقطة استلام الشحنات للفرع") ?? "اعتماد نقطة استلام الشحنات للفرع")
                            .font(PPBeirutiFont.bold(16, relativeTo: .headline))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        LinearGradient(
                            colors: [Color(uiColor: .ppPrimary), Color(uiColor: .ppPrimaryDarker)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                    )
                    .shadow(color: Color(uiColor: .ppPrimary).opacity(0.28), radius: 10, y: 4)
                }
                .ppTactile()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 32)
            .background(
                Color(uiColor: .ppBackground)
                    .shadow(color: .black.opacity(0.14), radius: 16, y: -4)
            )
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

// MARK: - Needle Triangle Shape

private struct PPLocationNeedleTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
