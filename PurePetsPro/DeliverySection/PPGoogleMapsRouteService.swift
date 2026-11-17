//
//  PPGoogleMapsRouteService.swift
//  PurePetsPro
//
//  Authoritative Google Maps Routes & Directions Service for Pure Pets Pro iOS.
//  Uses Google Routes API (v2 computeRoutes) with the configured Google Maps API key
//  to fetch traffic-aware driving routes, polyline geometry, and step-by-step
//  turn-by-turn directions in Arabic (RTL) and English (LTR).
//

import Foundation
import CoreLocation

// MARK: - Maneuver Types

public struct PPRouteManeuver: Sendable, Equatable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let depart = PPRouteManeuver(rawValue: "DEPART")
    public static let turnLeft = PPRouteManeuver(rawValue: "TURN_LEFT")
    public static let turnRight = PPRouteManeuver(rawValue: "TURN_RIGHT")
    public static let turnSlightLeft = PPRouteManeuver(rawValue: "TURN_SLIGHT_LEFT")
    public static let turnSlightRight = PPRouteManeuver(rawValue: "TURN_SLIGHT_RIGHT")
    public static let turnSharpLeft = PPRouteManeuver(rawValue: "TURN_SHARP_LEFT")
    public static let turnSharpRight = PPRouteManeuver(rawValue: "TURN_SHARP_RIGHT")
    public static let uTurnLeft = PPRouteManeuver(rawValue: "U_TURN_LEFT")
    public static let uTurnRight = PPRouteManeuver(rawValue: "U_TURN_RIGHT")
    public static let straight = PPRouteManeuver(rawValue: "STRAIGHT")
    public static let rampLeft = PPRouteManeuver(rawValue: "RAMP_LEFT")
    public static let rampRight = PPRouteManeuver(rawValue: "RAMP_RIGHT")
    public static let merge = PPRouteManeuver(rawValue: "MERGE")
    public static let forkLeft = PPRouteManeuver(rawValue: "FORK_LEFT")
    public static let forkRight = PPRouteManeuver(rawValue: "FORK_RIGHT")
    public static let roundaboutLeft = PPRouteManeuver(rawValue: "ROUNDABOUT_LEFT")
    public static let roundaboutRight = PPRouteManeuver(rawValue: "ROUNDABOUT_RIGHT")
    public static let arrive = PPRouteManeuver(rawValue: "ARRIVE")
    public static let nameChange = PPRouteManeuver(rawValue: "NAME_CHANGE")

    public var sfSymbol: String {
        switch rawValue.uppercased() {
        case "DEPART":
            return "location.north.fill"
        case "TURN_LEFT", "TURN_SHARP_LEFT":
            return "arrow.turn.up.left"
        case "TURN_SLIGHT_LEFT":
            return "arrow.up.left"
        case "TURN_RIGHT", "TURN_SHARP_RIGHT":
            return "arrow.turn.up.right"
        case "TURN_SLIGHT_RIGHT":
            return "arrow.up.right"
        case "UTURN_LEFT", "UTURN_RIGHT", "U_TURN_LEFT", "U_TURN_RIGHT":
            return "arrow.uturn.down"
        case "STRAIGHT", "NAME_CHANGE":
            return "arrow.up"
        case "ROUNDABOUT_LEFT", "ROUNDABOUT_RIGHT":
            return "arrow.triangle.turn.up.right.diamond.fill"
        case "RAMP_LEFT", "FORK_LEFT":
            return "arrow.triangle.branch"
        case "RAMP_RIGHT", "FORK_RIGHT":
            return "arrow.triangle.branch"
        case "MERGE":
            return "arrow.merge"
        case "ARRIVE":
            return "mappin.circle.fill"
        default:
            return "arrow.up"
        }
    }
}

// MARK: - Route Step

public struct PPRouteStep: Identifiable, Sendable, Equatable {
    public let id: String
    public let stepNumber: Int
    public let instructions: String
    public let maneuver: PPRouteManeuver
    public let distanceText: String
    public let durationText: String
    public let startCoordinate: CLLocationCoordinate2D
    public let endCoordinate: CLLocationCoordinate2D

    public static func == (lhs: PPRouteStep, rhs: PPRouteStep) -> Bool {
        lhs.id == rhs.id &&
        lhs.stepNumber == rhs.stepNumber &&
        lhs.instructions == rhs.instructions &&
        lhs.maneuver == rhs.maneuver &&
        lhs.distanceText == rhs.distanceText
    }
}

// MARK: - Route Info

public struct PPRouteInfo: Sendable, Equatable {
    public let distanceMeters: Int
    public let distanceFormatted: String
    public let durationSeconds: Int
    public let durationFormatted: String
    public let encodedPolyline: String
    public let polylineCoordinates: [CLLocationCoordinate2D]
    public let steps: [PPRouteStep]

    public static func == (lhs: PPRouteInfo, rhs: PPRouteInfo) -> Bool {
        lhs.distanceMeters == rhs.distanceMeters &&
        lhs.durationSeconds == rhs.durationSeconds &&
        lhs.encodedPolyline == rhs.encodedPolyline &&
        lhs.steps.count == rhs.steps.count
    }
}

// MARK: - Google Maps Route Service

public final class PPGoogleMapsRouteService: Sendable {
    public static let shared = PPGoogleMapsRouteService()

    /// Google Maps API Key provided for in-app route view and directions.
    public static let apiKey = "AIzaSyAwKg3h1jqzfJysZM17uRxYiM-w_Uc58ZE"

    private let urlSession: URLSession

    public init(session: URLSession = .shared) {
        self.urlSession = session
    }

    // MARK: - Compute Route

    /// Returns only a real road route. A rejected request is never represented
    /// as a straight line, an invented ETA, or fabricated driving instructions.
    public func fetchRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        isArabic: Bool
    ) async throws -> PPRouteInfo {
        guard Self.isUsable(origin), Self.isUsable(destination) else {
            throw PPRouteServiceError.invalidCoordinates
        }
        let endpoint = URL(string: "https://routes.googleapis.com/directions/v2:computeRoutes")!
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Self.apiKey, forHTTPHeaderField: "X-Goog-Api-Key")
        // Maneuver is nested inside navigationInstruction, never directly in steps.
        request.setValue(
            "routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline," +
            "routes.legs.steps.navigationInstruction,routes.legs.steps.localizedValues," +
            "routes.legs.steps.startLocation,routes.legs.steps.endLocation",
            forHTTPHeaderField: "X-Goog-FieldMask"
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "origin": ["location": ["latLng": ["latitude": origin.latitude, "longitude": origin.longitude]]],
            "destination": ["location": ["latLng": ["latitude": destination.latitude, "longitude": destination.longitude]]],
            "travelMode": "DRIVE",
            "routingPreference": "TRAFFIC_AWARE",
            "languageCode": isArabic ? "ar" : "en"
        ])
        let (data, response) = try await urlSession.data(for: request)
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw PPRouteServiceError.serviceUnavailable
        }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let routes = json["routes"] as? [[String: Any]] else {
            throw PPRouteServiceError.invalidResponse
        }
        guard let route = routes.first else { throw PPRouteServiceError.noDrivingRoute }
        guard let distance = route["distanceMeters"] as? NSNumber,
              distance.doubleValue.isFinite, distance.doubleValue >= 0, distance.doubleValue < Double(Int.max / 4),
              let duration = route["duration"] as? String,
              let seconds = Double(duration.replacingOccurrences(of: "s", with: "")),
              seconds.isFinite, seconds >= 0, seconds < Double(Int.max / 4),
              let polyline = (route["polyline"] as? [String: Any])?["encodedPolyline"] as? String else {
            throw PPRouteServiceError.invalidResponse
        }
        let coordinates = decodePolyline(polyline)
        guard coordinates.count >= 2 else { throw PPRouteServiceError.invalidResponse }
        var parsedSteps: [PPRouteStep] = []
        for leg in route["legs"] as? [[String: Any]] ?? [] {
            for item in leg["steps"] as? [[String: Any]] ?? [] {
                guard let start = Self.coordinate(item["startLocation"]),
                      let end = Self.coordinate(item["endLocation"]) else { continue }
                let instruction = item["navigationInstruction"] as? [String: Any] ?? [:]
                let text = (instruction["instructions"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                // Missing instructions stay missing; do not invent a maneuver.
                guard !text.isEmpty else { continue }
                let values = item["localizedValues"] as? [String: Any] ?? [:]
                parsedSteps.append(PPRouteStep(
                    id: "step_\(parsedSteps.count)", stepNumber: parsedSteps.count + 1,
                    instructions: text,
                    maneuver: PPRouteManeuver(rawValue: instruction["maneuver"] as? String ?? "MANEUVER_UNSPECIFIED"),
                    distanceText: (values["distance"] as? [String: Any])?["text"] as? String ?? "",
                    durationText: (values["staticDuration"] as? [String: Any])?["text"] as? String ?? "",
                    startCoordinate: start, endCoordinate: end
                ))
            }
        }
        let meters = distance.intValue
        return PPRouteInfo(
            distanceMeters: meters,
            distanceFormatted: formatDistance(meters: meters, isArabic: isArabic),
            durationSeconds: Int(seconds.rounded()),
            durationFormatted: formatDuration(seconds: Int(seconds.rounded()), isArabic: isArabic),
            encodedPolyline: polyline, polylineCoordinates: coordinates, steps: parsedSteps
        )
    }

    public static func isUsable(_ coordinate: CLLocationCoordinate2D) -> Bool {
        CLLocationCoordinate2DIsValid(coordinate) && coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite && (coordinate.latitude != 0 || coordinate.longitude != 0)
    }

    private static func coordinate(_ value: Any?) -> CLLocationCoordinate2D? {
        guard let dict = value as? [String: Any], let latLng = dict["latLng"] as? [String: Any],
              let lat = latLng["latitude"] as? Double, let lng = latLng["longitude"] as? Double else { return nil }
        let result = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        return isUsable(result) ? result : nil
    }

    // MARK: - Geocoding Helpers

    /// Exact coordinates and coordinate-bearing map links take precedence over geocoding.
    /// Unresolvable addresses remain nil; no default city is ever substituted.
    public func resolveCoordinate(address: String) async -> CLLocationCoordinate2D? {
        let clean = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !Task.isCancelled else { return nil }
        if let coordinate = Self.coordinateQuery(clean) { return coordinate }
        if let url = URLComponents(string: clean), url.scheme != nil {
            for name in ["query", "q", "daddr", "destination", "ll"] {
                if let value = url.queryItems?.first(where: { $0.name == name })?.value,
                   let coordinate = Self.coordinateQuery(value) { return coordinate }
            }
            // A URL is not a postal address and must not geocode to an unrelated place.
            return nil
        }
        do {
            let results = try await CLGeocoder().geocodeAddressString(clean)
            guard !Task.isCancelled, let coordinate = results.first?.location?.coordinate,
                  Self.isUsable(coordinate) else { return nil }
            return coordinate
        } catch { return nil }
    }

    private static func coordinateQuery(_ value: String) -> CLLocationCoordinate2D? {
        let ascii = value.map { character -> String in
            if let digit = character.wholeNumberValue, (0...9).contains(digit) { return String(digit) }
            return String(character)
        }.joined()
        let parts = ascii.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard parts.count == 2, let lat = Double(parts[0]), let lng = Double(parts[1]) else { return nil }
        let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        return isUsable(coordinate) ? coordinate : nil
    }

    // MARK: - Polyline decoding

    /// Bounded decoding rejects truncated/overflowing input instead of crashing or
    /// drawing a partial line that could be mistaken for a driving route.
    public func decodePolyline(_ encoded: String) -> [CLLocationCoordinate2D] {
        let bytes = Array(encoded.utf8)
        var index = 0
        var latitude: Int64 = 0, longitude: Int64 = 0
        var result: [CLLocationCoordinate2D] = []
        func component() -> Int64? {
            var value: Int64 = 0
            for shift in stride(from: 0, through: 30, by: 5) {
                guard index < bytes.count, (63...126).contains(bytes[index]) else { return nil }
                let chunk = Int64(bytes[index] - 63)
                index += 1
                value |= (chunk & 31) << shift
                if chunk < 32 { return value & 1 == 1 ? ~(value >> 1) : value >> 1 }
            }
            return nil
        }
        while index < bytes.count {
            guard let lat = component(), let lng = component() else { return [] }
            latitude += lat; longitude += lng
            let coordinate = CLLocationCoordinate2D(latitude: Double(latitude) * 1e-5,
                                                    longitude: Double(longitude) * 1e-5)
            guard CLLocationCoordinate2DIsValid(coordinate) else { return [] }
            result.append(coordinate)
        }
        return result
    }

    // MARK: - Locale-aware route metrics

    public func formatDistance(meters: Int, isArabic: Bool) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: isArabic ? "ar" : "en")
        formatter.maximumFractionDigits = meters < 1000 ? 0 : 1
        let amount = formatter.string(from: NSNumber(value: meters < 1000 ? Double(meters) : Double(meters) / 1000)) ?? ""
        let key = meters < 1000 ? "ProRoute_DistanceMeters" : "ProRoute_DistanceKilometers"
        let path = Bundle.main.path(forResource: isArabic ? "ar" : "en", ofType: "lproj")
        let bundle = path.flatMap { Bundle(path: $0) } ?? .main
        return String(format: bundle.localizedString(forKey: key, value: nil, table: nil), amount)
    }

    public func formatDuration(seconds: Int, isArabic: Bool) -> String {
        let formatter = DateComponentsFormatter()
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: isArabic ? "ar" : "en")
        formatter.calendar = calendar
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter.string(from: TimeInterval(max(60, seconds))) ?? ""
    }
}

/// UI maps these typed failures through the existing localized text helper.
public enum PPRouteServiceError: Error, Sendable {
    case invalidCoordinates, serviceUnavailable, invalidResponse, noDrivingRoute
}
