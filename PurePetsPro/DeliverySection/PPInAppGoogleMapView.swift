//
//  PPInAppGoogleMapView.swift
//  PurePetsPro
//
//  Category-Defining In-App Google Maps View for iOS Pro.
//  Supports dynamic roadmap/satellite/terrain views, pickup & dropoff pins, live driver location,
//  and traffic-aware polyline drawing.
//

import SwiftUI
import WebKit
import CoreLocation

public enum PPMapStyleType: String, CaseIterable, Sendable, Hashable {
    case roadmap = "roadmap"
    case hybrid = "hybrid"
    case terrain = "terrain"
}

public struct PPInAppGoogleMapView: UIViewRepresentable {
    public let pickupCoordinate: CLLocationCoordinate2D?
    public let dropoffCoordinate: CLLocationCoordinate2D?
    public let polylineCoordinates: [CLLocationCoordinate2D]
    public let driverCoordinate: CLLocationCoordinate2D?
    public let driverHeading: Double?
    public let mapStyle: PPMapStyleType
    public let pickupTitle: String
    public let dropoffTitle: String
    public let driverTitle: String
    public let isArabic: Bool
    public let isDarkMode: Bool
    public let recenterTrigger: Int
    public var routeRevision: Int = 0
    public var locationTrigger: Int = 0
    public var focusTrigger: Int = 0
    public var focusedCoordinate: CLLocationCoordinate2D?
    public var onMapFailure: @MainActor () -> Void = {}
    public var onMapReady: @MainActor () -> Void = {}
    public var reduceMotion = false

    public init(
        pickupCoordinate: CLLocationCoordinate2D?,
        dropoffCoordinate: CLLocationCoordinate2D?,
        polylineCoordinates: [CLLocationCoordinate2D],
        driverCoordinate: CLLocationCoordinate2D? = nil,
        driverHeading: Double? = nil,
        mapStyle: PPMapStyleType = .roadmap,
        pickupTitle: String,
        dropoffTitle: String,
        driverTitle: String,
        isArabic: Bool = false,
        isDarkMode: Bool = true,
        recenterTrigger: Int = 0,
        routeRevision: Int = 0,
        locationTrigger: Int = 0,
        focusTrigger: Int = 0,
        focusedCoordinate: CLLocationCoordinate2D? = nil,
        reduceMotion: Bool = false,
        onMapFailure: @escaping @MainActor () -> Void = {},
        onMapReady: @escaping @MainActor () -> Void = {}
    ) {
        self.pickupCoordinate = pickupCoordinate
        self.dropoffCoordinate = dropoffCoordinate
        self.polylineCoordinates = polylineCoordinates
        self.driverCoordinate = driverCoordinate
        self.driverHeading = driverHeading
        self.mapStyle = mapStyle
        self.pickupTitle = pickupTitle
        self.dropoffTitle = dropoffTitle
        self.driverTitle = driverTitle
        self.isArabic = isArabic
        self.isDarkMode = isDarkMode
        self.recenterTrigger = recenterTrigger
        self.routeRevision = routeRevision
        self.locationTrigger = locationTrigger
        self.focusTrigger = focusTrigger
        self.focusedCoordinate = focusedCoordinate
        self.reduceMotion = reduceMotion
        self.onMapFailure = onMapFailure
        self.onMapReady = onMapReady
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "mapReady")
        userContentController.add(context.coordinator, name: "mapFailed")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = isDarkMode ? UIColor(red: 0.05, green: 0.08, blue: 0.14, alpha: 1.0) : UIColor(red: 0.96, green: 0.97, blue: 0.99, alpha: 1.0)
        webView.scrollView.isScrollEnabled = false
        webView.navigationDelegate = context.coordinator

        context.coordinator.webView = webView
        context.coordinator.startReadinessDeadline()
        loadMapHTML(in: webView)
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self

        guard context.coordinator.isMapReady else { return }

        // Coordinates and route geometry arrive asynchronously after mapReady.
        // Push changed data instead of leaving the initial empty map in place.
        webView.evaluateJavaScript("reduceMotionPreference = \(reduceMotion ? "true" : "false");", completionHandler: nil)
        context.coordinator.synchronizeRouteData()

        // Update map type
        context.coordinator.updateMapType(mapStyle)

        // Update driver position
        if let driver = driverCoordinate {
            context.coordinator.updateDriver(lat: driver.latitude, lng: driver.longitude, heading: driverHeading)
        } else {
            webView.evaluateJavaScript("clearDriverPosition();", completionHandler: nil)
        }

        if context.coordinator.lastLocationTrigger != locationTrigger {
            context.coordinator.lastLocationTrigger = locationTrigger
            if let driverCoordinate { context.coordinator.focus(coordinate: driverCoordinate) }
        }
        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            if let focusedCoordinate { context.coordinator.focus(coordinate: focusedCoordinate) }
        }

        // Check if recenter requested
        if context.coordinator.lastRecenterTrigger != recenterTrigger {
            context.coordinator.lastRecenterTrigger = recenterTrigger
            context.coordinator.fitRoute()
        }
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.stopLoading()
        webView.navigationDelegate = nil
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "mapReady")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "mapFailed")
        coordinator.webView = nil
        coordinator.readinessTask?.cancel()
    }

    private func loadMapHTML(in webView: WKWebView) {
        let html = generateHTML()
        webView.loadHTMLString(html, baseURL: URL(string: "https://maps.googleapis.com"))
    }

    private func generateHTML() -> String {
        let initial = pickupCoordinate ?? dropoffCoordinate ?? driverCoordinate
        let initialLat = initial?.latitude ?? 30.0444
        let initialLng = initial?.longitude ?? 31.2357
        let initialZoom = initial == nil ? 12 : 14
        let bgHex = isDarkMode ? "#0F172A" : "#F8FAFC"

        let darkStyles = """
        [
          { "elementType": "geometry", "stylers": [{"color": "#1e293b"}] },
          { "elementType": "labels.text.stroke", "stylers": [{"color": "#0f172a"}] },
          { "elementType": "labels.text.fill", "stylers": [{"color": "#94a3b8"}] },
          { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [{"color": "#e2e8f0"}] },
          { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#38bdf8"}] },
          { "featureType": "road", "elementType": "geometry", "stylers": [{"color": "#334155"}] },
          { "featureType": "road", "elementType": "geometry.stroke", "stylers": [{"color": "#1e293b"}] },
          { "featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#475569"}] },
          { "featureType": "transit", "elementType": "geometry", "stylers": [{"color": "#1e293b"}] },
          { "featureType": "water", "elementType": "geometry", "stylers": [{"color": "#0284c7"}] }
        ]
        """

        let lightStyles = """
        [
          { "featureType": "water", "elementType": "geometry", "stylers": [{"color": "#e9e9e9"}, {"lightness": 17}] },
          { "featureType": "landscape", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 20}] },
          { "featureType": "road.highway", "elementType": "geometry.fill", "stylers": [{"color": "#ffffff"}, {"lightness": 17}] },
          { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#ffffff"}, {"lightness": 29}, {"weight": 0.2}] },
          { "featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 18}] },
          { "featureType": "road.local", "elementType": "geometry", "stylers": [{"color": "#ffffff"}, {"lightness": 16}] },
          { "featureType": "poi", "elementType": "geometry", "stylers": [{"color": "#f5f5f5"}, {"lightness": 21}] },
          { "featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#dedede"}, {"lightness": 21}] }
        ]
        """

        let stylesToUse = isDarkMode ? darkStyles : lightStyles

        return """
        <!DOCTYPE html>
        <html lang="\(isArabic ? "ar" : "en")" dir="\(isArabic ? "rtl" : "ltr")">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
          <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            html, body, #map { width: 100%; height: 100%; overflow: hidden; background-color: \(bgHex); }
          </style>
          <script>
            function reportMapFailure() {
              window.webkit?.messageHandlers?.mapFailed?.postMessage({status:'failed'});
            }
            window.gm_authFailure = reportMapFailure;
          </script>
          <script onerror="reportMapFailure()" src="https://maps.googleapis.com/maps/api/js?key=\(PPGoogleMapsRouteService.apiKey)&libraries=geometry&language=\(isArabic ? "ar" : "en")"></script>
        </head>
        <body>
          <div id="map"></div>
          <script>
            let map, pickupMarker, dropoffMarker, driverMarker, routePolyline, routeGlow;
            let reduceMotionPreference = \(reduceMotion ? "true" : "false");
            const PIN_SVG_PATH = 'M12 2C8.13 2 5 5.13 5 9c0 5.25 7 13 7 13s7-7.75 7-13c0-3.87-3.13-7-7-7zm0 9.5a2.5 2.5 0 0 1 0-5 2.5 2.5 0 0 1 0 5z';

            function fitVisibleBounds(bounds) {
              if (!reduceMotionPreference) { map.fitBounds(bounds, 28); return; }
              const ne = bounds.getNorthEast(), sw = bounds.getSouthWest();
              const mercator = latitude => Math.log(Math.tan(Math.PI / 4 + latitude * Math.PI / 360));
              const latFraction = Math.abs(mercator(Math.min(85, ne.lat())) - mercator(Math.max(-85, sw.lat()))) / (2 * Math.PI);
              let longitudeSpan = ne.lng() - sw.lng();
              if (longitudeSpan < 0) longitudeSpan += 360;
              const lngFraction = longitudeSpan / 360;
              const size = map.getDiv();
              const zoomFor = (pixels, fraction) => fraction > 0 ? Math.floor(Math.log2(Math.max(1, pixels - 56) / (256 * fraction))) : 18;
              const zoom = Math.max(1, Math.min(18, zoomFor(size.clientWidth, lngFraction), zoomFor(size.clientHeight, latFraction)));
              // moveCamera is immediate, unlike fitBounds' internal animation heuristic.
              map.moveCamera({center: bounds.getCenter(), zoom: zoom});
            }
            
            function initMap() {
              if (!window.google?.maps) { reportMapFailure(); return; }
              map = new google.maps.Map(document.getElementById('map'), {
                center: { lat: \(initialLat), lng: \(initialLng) },
                zoom: \(initialZoom),
                disableDefaultUI: true,
                gestureHandling: 'greedy',
                mapTypeId: '\(mapStyle.rawValue)',
                styles: \(stylesToUse)
              });
              
              if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapReady) {
                window.webkit.messageHandlers.mapReady.postMessage({ status: 'ready' });
              }
            }
            
            function renderRouteData(pickup, dropoff, polyCoords, pickupLbl, dropoffLbl) {
              if (!map) return;
              
              if (pickupMarker) pickupMarker.setMap(null);
              if (dropoffMarker) dropoffMarker.setMap(null);
              if (routePolyline) routePolyline.setMap(null);
              if (routeGlow) routeGlow.setMap(null);
              pickupMarker = null; dropoffMarker = null;
              routePolyline = null; routeGlow = null;
              
              const bounds = new google.maps.LatLngBounds();
              
              if (pickup && Number.isFinite(pickup.lat) && Number.isFinite(pickup.lng)) {
                const pPos = new google.maps.LatLng(pickup.lat, pickup.lng);
                pickupMarker = new google.maps.Marker({
                  position: pPos,
                  map: map,
                  title: pickupLbl,
                  zIndex: 900,
                  icon: {
                    path: PIN_SVG_PATH,
                    scale: 1.6,
                    fillColor: '#0284C7',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 1.8,
                    anchor: (window.google?.maps?.Point ? new google.maps.Point(12, 22) : null)
                  }
                });
                bounds.extend(pPos);
              }
              
              if (dropoff && Number.isFinite(dropoff.lat) && Number.isFinite(dropoff.lng)) {
                const dPos = new google.maps.LatLng(dropoff.lat, dropoff.lng);
                dropoffMarker = new google.maps.Marker({
                  position: dPos,
                  map: map,
                  title: dropoffLbl,
                  zIndex: 950,
                  icon: {
                    path: PIN_SVG_PATH,
                    scale: 1.6,
                    fillColor: '#E11D48',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 1.8,
                    anchor: (window.google?.maps?.Point ? new google.maps.Point(12, 22) : null)
                  }
                });
                bounds.extend(dPos);
              }
              
              if (polyCoords && polyCoords.length > 0) {
                // Fit the chosen driving leg and include stop pins.
                const routeBounds = new google.maps.LatLngBounds();
                const path = polyCoords.map(c => new google.maps.LatLng(c.lat, c.lng));
                
                // Outer glow
                routeGlow = new google.maps.Polyline({
                  path: path,
                  geodesic: true,
                  strokeColor: '#065F46',
                  strokeOpacity: 0.6,
                  strokeWeight: 9,
                  map: map
                });
                
                // Main high-contrast emerald route line
                routePolyline = new google.maps.Polyline({
                  path: path,
                  geodesic: true,
                  strokeColor: '#10B981',
                  strokeOpacity: 0.98,
                  strokeWeight: 6,
                  map: map
                });
                
                path.forEach(pt => routeBounds.extend(pt));
                fitVisibleBounds(routeBounds);
                return;
              }
              
              if (!bounds.isEmpty()) {
                if (pickupMarker && !dropoffMarker) {
                  map.setCenter(pickupMarker.getPosition()); map.setZoom(15);
                } else if (dropoffMarker && !pickupMarker) {
                  map.setCenter(dropoffMarker.getPosition()); map.setZoom(15);
                } else { fitVisibleBounds(bounds); }
              }
            }
            
            function updateDriverPosition(lat, lng, heading) {
              if (!map) return;
              const pos = new google.maps.LatLng(lat, lng);
              if (!driverMarker) {
                driverMarker = new google.maps.Marker({
                  position: pos,
                  map: map,
                  title: \(jsonString(driverTitle)),
                  zIndex: 999,
                  icon: {
                    path: PIN_SVG_PATH,
                    scale: 1.6,
                    fillColor: '#10B981',
                    fillOpacity: 1,
                    strokeColor: '#FFFFFF',
                    strokeWeight: 1.8,
                    anchor: (window.google?.maps?.Point ? new google.maps.Point(12, 22) : null)
                  }
                });
              } else {
                driverMarker.setPosition(pos);
              }
            }
            
            function setMapTypeId(type) {
              if (!map) return;
              map.setMapTypeId(type);
            }

            function clearDriverPosition() {
              if (driverMarker) driverMarker.setMap(null);
              driverMarker = null;
            }
            
            function fitBoundsAll() {
              if (!map) return;
              const bounds = new google.maps.LatLngBounds();
              if (routePolyline) {
                routePolyline.getPath().forEach(pt => bounds.extend(pt));
              } else {
                if (pickupMarker) bounds.extend(pickupMarker.getPosition());
                if (dropoffMarker) bounds.extend(dropoffMarker.getPosition());
                if (driverMarker) bounds.extend(driverMarker.getPosition());
              }
              if (!bounds.isEmpty()) {
                fitVisibleBounds(bounds);
              }
            }
            
            function focusCoord(lat, lng, zoomLevel, reduceMotion) {
              if (!map) return;
              const position = new google.maps.LatLng(lat, lng);
              if (reduceMotion) { map.setCenter(position); }
              else { map.panTo(position); }
              map.setZoom(zoomLevel || 16);
            }
            
            window.onload = initMap;
          </script>
        </body>
        </html>
        """
    }

    private func jsonString(_ value: String) -> String {
        guard let data = try? JSONEncoder().encode(value), let result = String(data: data, encoding: .utf8) else { return "\"\"" }
        return result.replacingOccurrences(of: "<", with: "\\u003C")
    }

    // MARK: - Coordinator

    public final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: PPInAppGoogleMapView
        weak var webView: WKWebView?
        var isMapReady = false
        var lastRecenterTrigger = 0
        var lastLocationTrigger = 0
        var lastFocusTrigger = 0
        private var lastRouteSignature: String?
        var readinessTask: Task<Void, Never>?

        init(_ parent: PPInAppGoogleMapView) {
            self.parent = parent
        }

        func startReadinessDeadline() {
            readinessTask?.cancel()
            readinessTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: .seconds(15)) } catch { return }
                guard let self, !self.isMapReady else { return }
                self.parent.onMapFailure()
            }
        }

        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "mapReady" {
                isMapReady = true
                readinessTask?.cancel()
                parent.onMapReady()
                synchronizeRouteData()
                if let driver = parent.driverCoordinate {
                    updateDriver(lat: driver.latitude, lng: driver.longitude, heading: parent.driverHeading)
                }
            } else if message.name == "mapFailed" {
                parent.onMapFailure()
            }
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.onMapFailure()
        }

        public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            parent.onMapFailure()
        }

        func synchronizeRouteData() {
            let signature = "\(parent.pickupCoordinate?.latitude ?? .nan),\(parent.pickupCoordinate?.longitude ?? .nan)|\(parent.dropoffCoordinate?.latitude ?? .nan),\(parent.dropoffCoordinate?.longitude ?? .nan)|\(parent.routeRevision)"
            guard signature != lastRouteSignature else { return }
            lastRouteSignature = signature
            sendRouteDataToMap()
        }

        public func sendRouteDataToMap() {
            guard let webView = webView, isMapReady else { return }

            let pDict: String = {
                if let p = parent.pickupCoordinate {
                    return "{ lat: \(p.latitude), lng: \(p.longitude) }"
                }
                return "null"
            }()

            let dDict: String = {
                if let d = parent.dropoffCoordinate {
                    return "{ lat: \(d.latitude), lng: \(d.longitude) }"
                }
                return "null"
            }()

            let coordsJS = parent.polylineCoordinates.map { "{ lat: \($0.latitude), lng: \($0.longitude) }" }.joined(separator: ", ")

            let script = "renderRouteData(\(pDict), \(dDict), [\(coordsJS)], '\(escapeJS(parent.pickupTitle))', '\(escapeJS(parent.dropoffTitle))');"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        public func updateDriver(lat: Double, lng: Double, heading: Double?) {
            guard let webView = webView, isMapReady else { return }
            let hVal = heading != nil ? "\(heading!)" : "null"
            let script = "updateDriverPosition(\(lat), \(lng), \(hVal));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        public func updateMapType(_ style: PPMapStyleType) {
            guard let webView = webView, isMapReady else { return }
            let script = "setMapTypeId('\(style.rawValue)');"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        public func fitRoute() {
            guard let webView = webView, isMapReady else { return }
            let script = "fitBoundsAll();"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        public func focus(coordinate: CLLocationCoordinate2D, zoom: Int = 16) {
            guard let webView = webView, isMapReady else { return }
            let script = "focusCoord(\(coordinate.latitude), \(coordinate.longitude), \(zoom), \(parent.reduceMotion ? "true" : "false"));"
            webView.evaluateJavaScript(script, completionHandler: nil)
        }

        private func escapeJS(_ string: String) -> String {
            string.replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
                .replacingOccurrences(of: "\n", with: " ")
        }
    }
}
