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

    /// The most accurate and recent location fix available.
    public var bestLocation: CLLocation? {
        if let location = currentLocation, isLocationUsable(location) {
            return location
        }
        if let location = locationManager.location, isLocationUsable(location) {
            return location
        }
        return currentLocation ?? locationManager.location
    }

    /// A valid location fix for live route viewing.
    public var usableLocation: CLLocation? {
        guard let location = bestLocation, isLocationUsable(location) else { return nil }
        return location
    }

    private func isLocationUsable(_ location: CLLocation) -> Bool {
        location.horizontalAccuracy >= 0 &&
        location.horizontalAccuracy <= 1500 &&
        abs(location.timestamp.timeIntervalSinceNow) <= 1800 &&
        PPGoogleMapsRouteService.isUsable(location.coordinate)
    }

    public override init() {
        self.authorizationStatus = locationManager.authorizationStatus
        super.init()
        self.locationManager.delegate = self
        self.locationManager.activityType = .automotiveNavigation
        self.locationManager.pausesLocationUpdatesAutomatically = true
        self.locationManager.desiredAccuracy = kCLLocationAccuracyBest
        self.locationManager.distanceFilter = 5.0
        self.locationManager.headingFilter = 5.0
        if let initial = locationManager.location, isLocationUsable(initial) {
            self.currentLocation = initial
        }
        PPProSessionCoordinator.shared().registerSessionTeardownHandler({ [weak self] _ in
            MainActor.assumeIsolated {
                self?.resetForSessionTeardown()
            }
        }, forKey: "PPDriverLocationTracker")
    }

    public func resetForSessionTeardown() {
        stopTracking()
        currentLocation = nil
        currentHeading = nil
        locationFailed = false
    }

    public func startTracking() {
        if let initial = locationManager.location, isLocationUsable(initial) {
            self.currentLocation = initial
        }
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
        if (manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways) {
            if let initial = manager.location, isLocationUsable(initial) {
                self.currentLocation = initial
            }
            if self.isTracking {
                self.locationManager.startUpdatingLocation()
                if CLLocationManager.headingAvailable() {
                    self.locationManager.startUpdatingHeading()
                }
            }
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last(where: { isLocationUsable($0) }) else { return }
        self.locationFailed = false
        self.currentLocation = latest
        let targetFilter: CLLocationDistance = latest.speed >= 1.5 ? 5.0 : 20.0
        if locationManager.distanceFilter != targetFilter {
            locationManager.distanceFilter = targetFilter
        }
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
