//
//  LocationService.swift
//  sweezy
//
//  Created by Vladyslav Katash on 14.10.2025.
//

import Foundation
import CoreLocation
import Combine

/// Protocol for location services
@MainActor
protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: CLLocation? { get }
    var authorizationStatus: CLAuthorizationStatus { get }
    var isLocationEnabled: Bool { get }
    
    func requestLocationPermission()
    func startLocationUpdates()
    func stopLocationUpdates()
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance?
    func nearbyPlaces(from places: [Place], radius: CLLocationDistance) -> [Place]
}

/// Location service implementation - lazy initialization to avoid blocking app startup
@MainActor
class LocationService: NSObject, LocationServiceProtocol {
    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLocationEnabled: Bool = false
    
    // Lazy initialization to avoid blocking app startup
    private var _locationManager: CLLocationManager?
    private var locationManager: CLLocationManager {
        if _locationManager == nil {
            let manager = CLLocationManager()
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 100
            let proxy = LocationManagerDelegateProxy(owner: self)
            self.delegateProxy = proxy
            manager.delegate = proxy
            _locationManager = manager
            authorizationStatus = manager.authorizationStatus
            updateLocationEnabledStatus()
        }
        return _locationManager!
    }
    
    private var delegateProxy: LocationManagerDelegateProxy?
    private var isUpdatingLocation = false
    
    override init() {
        super.init()
        // Don't setup location manager here - do it lazily
    }
    
    func requestLocationPermission() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            // Guide user to settings
            break
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    func startLocationUpdates() {
        guard isLocationEnabled && !isUpdatingLocation else { return }
        
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        guard isUpdatingLocation else { return }
        
        isUpdatingLocation = false
        _locationManager?.stopUpdatingLocation()
    }
    
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }
    
    func nearbyPlaces(from places: [Place], radius: CLLocationDistance = 10000) -> [Place] {
        guard let currentLocation = currentLocation else { return [] }
        
        return places
            .filter { place in
                place.distance(from: currentLocation) <= radius
            }
            .sorted { place1, place2 in
                place1.distance(from: currentLocation) < place2.distance(from: currentLocation)
            }
    }
    
    private func updateLocationEnabledStatus() {
        let status = _locationManager?.authorizationStatus ?? .notDetermined
        isLocationEnabled = status == .authorizedWhenInUse || status == .authorizedAlways
    }
}

// MARK: - Delegate Proxy (nonisolated)

private final class LocationManagerDelegateProxy: NSObject, CLLocationManagerDelegate {
    weak var owner: LocationService?
    init(owner: LocationService) { self.owner = owner }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            owner?.handleDidUpdateLocations(locations)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            owner?.handleDidFailWithError(error)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            owner?.handleDidChangeAuthorization(status)
        }
    }
}

// MARK: - Main actor handlers

extension LocationService {
    fileprivate func handleDidUpdateLocations(_ locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        if let currentLocation = currentLocation {
            let distance = location.distance(from: currentLocation)
            let isMoreAccurate = location.horizontalAccuracy < currentLocation.horizontalAccuracy
            let isSignificantlyDifferent = distance > 100
            if !isMoreAccurate && !isSignificantlyDifferent { return }
        }
        currentLocation = location
    }
    
    fileprivate func handleDidFailWithError(_ error: Error) {
        print("Location manager failed with error: \(error)")
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                stopLocationUpdates()
            case .locationUnknown:
                break
            case .network:
                break
            default:
                break
            }
        }
    }
    
    fileprivate func handleDidChangeAuthorization(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        updateLocationEnabledStatus()
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        case .denied, .restricted:
            stopLocationUpdates()
            currentLocation = nil
        case .notDetermined:
            break
        @unknown default:
            break
        }
    }
}

// MARK: - Location Utilities

extension LocationService {
    /// Format distance for display
    static func formatDistance(_ distance: CLLocationDistance) -> String {
        let formatter = MeasurementFormatter()
        formatter.unitOptions = .naturalScale
        formatter.numberFormatter.maximumFractionDigits = 1
        
        let measurement = Measurement(value: distance, unit: UnitLength.meters)
        return formatter.string(from: measurement)
    }
    
    /// Get approximate address from coordinates
    func reverseGeocode(coordinate: CLLocationCoordinate2D) async -> String? {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            
            var addressComponents: [String] = []
            
            if let street = placemark.thoroughfare {
                addressComponents.append(street)
            }
            
            if let houseNumber = placemark.subThoroughfare {
                addressComponents.append(houseNumber)
            }
            
            if let city = placemark.locality {
                addressComponents.append(city)
            }
            
            if let postalCode = placemark.postalCode {
                addressComponents.append(postalCode)
            }
            
            return addressComponents.joined(separator: ", ")
        } catch {
            print("Reverse geocoding failed: \(error)")
            return nil
        }
    }
    
    /// Get coordinates from address string
    func geocode(address: String) async -> CLLocationCoordinate2D? {
        let geocoder = CLGeocoder()
        
        do {
            let placemarks = try await geocoder.geocodeAddressString(address)
            return placemarks.first?.location?.coordinate
        } catch {
            print("Geocoding failed: \(error)")
            return nil
        }
    }
}
