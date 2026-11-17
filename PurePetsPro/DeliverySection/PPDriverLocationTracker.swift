//
//  PPDriverLocationTracker.swift
//  PurePetsPro
//
//  Real-time Driver GPS Telemetry & Heading Manager for In-App Live Route.
//  Streams foreground device location to the interactive Google Map and
//  computes distance to upcoming navigation steps.
//

import Foundation
import CoreLocation
import Combine

@MainActor
public final class PPDriverLocationTracker: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    public static let shared = PPDriverLocationTracker()

    @Published public private(set) var currentLocation: CLLocation?
    @Published public private(set) var currentHeading: CLHeading?
    @Published public private(set) var authorizationStatus: CLAuthorizationStatus
    @Published public private(set) var locationFailed = false

    private let locationManager = CLLocationManager()
    private var isTracking = false

    /// A cached or invalid fix cannot become the origin of a driving route.
    public var usableLocation: CLLocation? {
        guard let location = currentLocation,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 200,
              abs(location.timestamp.timeIntervalSinceNow) <= 60,
              PPGoogleMapsRouteService.isUsable(location.coordinate) else { return nil }
        return location
    }

    public override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        self.locationManager.distanceFilter = 3.0 // 3 meters
        self.locationManager.headingFilter = 3.0 // 3 degrees
    }

    public func startTracking() {
        guard !isTracking else { return }
        isTracking = true
        locationFailed = false

        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        } else if status == .authorizedWhenInUse || status == .authorizedAlways {
            locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                locationManager.startUpdatingHeading()
            }
        }
    }

    public func stopTracking() {
        guard isTracking else { return }
        isTracking = false
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    // MARK: - Navigation Step Proximity Helper

    /// Finds the index of the step currently being traversed by comparing driver position to step end coordinates.
    public func findActiveStepIndex(in steps: [PPRouteStep], driverLocation: CLLocation) -> Int {
        guard !steps.isEmpty else { return 0 }
        for (index, step) in steps.enumerated() {
            let endLoc = CLLocation(latitude: step.endCoordinate.latitude, longitude: step.endCoordinate.longitude)
            let distance = driverLocation.distance(from: endLoc)
            // If driver is more than 35 meters away from this step's end, they are still on this step
            if distance > 35 {
                return index
            }
        }
        return max(0, steps.count - 1)
    }

    // MARK: - CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        if manager.authorizationStatus == .denied || manager.authorizationStatus == .restricted {
            currentLocation = nil
            currentHeading = nil
        }
        if self.isTracking && (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
            self.locationManager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                self.locationManager.startUpdatingHeading()
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last(where: {
            $0.horizontalAccuracy >= 0 && $0.horizontalAccuracy <= 200 &&
            abs($0.timestamp.timeIntervalSinceNow) <= 60 &&
            PPGoogleMapsRouteService.isUsable($0.coordinate)
        }) else { return }
        self.locationFailed = false
        self.currentLocation = latest
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        self.currentHeading = newHeading
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Transient missing fixes may recover, but the UI must offer retry.
        self.locationFailed = true
    }
}
