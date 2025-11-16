import Foundation
import CoreLocation

final class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var lastLocation: CLLocation?

    private let manager: CLLocationManager

    override init() {
        self.manager = CLLocationManager()
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestWhenInUse() {
        manager.requestWhenInUseAuthorization()
    }

    func start() {
        manager.startUpdatingLocation()
    }

    func stop() {
        manager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            start()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        lastLocation = locations.last
        stop()
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handle errors if needed
    }
}
