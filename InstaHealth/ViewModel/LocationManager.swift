//
//  LocationManager.swift
//  InstaHealth
//
//  Created by Michael Law on 4/10/23.
//

import SwiftUI
import CoreLocation
import MapKit

// combine framework to watch textfield change
import Combine

class LocationManager: NSObject,ObservableObject,MKMapViewDelegate,CLLocationManagerDelegate {
    @Published var mapView: MKMapView = .init()
    @Published var manager: CLLocationManager = .init()
    
    // search bar text
    @Published var searchText: String = ""
    var cancellable: AnyCancellable?
    @Published var fetchedPlaces: [CLPlacemark]?
    
    // User Location
    @Published var userLocation: CLLocation?
    
    // Final Location
    @Published var pickedLocation: CLLocation?
    @Published var pickedPlaceMark: CLPlacemark?
    
    // Payload for POST Request
    @Published var finalPayload: [String: String]?
    
    /// Initializes the view controller and sets up necessary components and delegates.
    override init() {
        super.init()
        // Set up delegates for location manager and map view
        manager.delegate = self
        mapView.delegate = self
        
        // requesting location access
        manager.requestWhenInUseAuthorization()
        
        // Watch the searchText property for changes and trigger fetching of places
        // Debounce the changes to avoid excessive requests
        // Remove duplicates to avoid redundant requests
        cancellable = $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink(receiveValue: { value in
                // Fetch places if search text is not empty, otherwise reset fetchedPlaces
                if value != ""{
                    self.fetchPlaces(value: value)
                }else{
                    self.fetchedPlaces = nil
                }
            })
    }
    
    /// Fetches places using MKLocalSearch based on a given search value.
    /// - Parameter value: The search value for fetching places.
    func fetchPlaces(value: String) {
        // Fetch places using MKLocalSearch in a Task to avoid blocking the main thread
        Task {
            do {
                // Create a request with the given search value
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = value.lowercased()
                
                // Start the search and await the response
                let response = try await MKLocalSearch(request: request).start()
                
                // Update the fetchedPlaces array on the main actor's queue
                await MainActor.run(body: {
                    self.fetchedPlaces = response.mapItems.compactMap({ item -> CLPlacemark in
                        return item.placemark
                    })
                })
            }
            catch {
                // Handle any errors that may occur during the search
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Handles error
        
    }
    
    // returns typed location term
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else{return}
        self.userLocation = currentLocation
    }
    
    /// Handles changes in the authorization status of the CLLocationManager.
    /// - Parameter manager: The CLLocationManager instance that triggered the authorization status change.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // Switch on the authorization status of the CLLocationManager
        switch manager.authorizationStatus {
        case .authorizedAlways:
            // If authorization is set to "Always", request the current location
            manager.requestLocation()
        case .authorizedWhenInUse:
            // If authorization is set to "When In Use", request the current location
            manager.requestLocation()
        case .denied:
            // If authorization is denied, handle the location error
            handleLocationError()
        case .notDetermined:
            // If authorization is not determined, request "When In Use" authorization
            manager.requestWhenInUseAuthorization()
        default:
            // For other cases, do nothing
            ()
        }
    }
    
    func handleLocationError(){
        // handles error
    }
    
    /// Adds a draggable pin to the MKMapView at the specified coordinate.
    /// - Parameter coordinate: The CLLocationCoordinate2D representing the location where the pin will be added.
    func addDraggablePin(coordinate: CLLocationCoordinate2D) {
        // Create an MKPointAnnotation object
        let annotation = MKPointAnnotation()
        
        // Set the coordinate of the annotation to the specified coordinate
        annotation.coordinate = coordinate
        
        // Set the title of the annotation
        annotation.title = "Clinic will be added here"
        
        // Add the annotation to the MKMapView
        mapView.addAnnotation(annotation)
    }
    
    /// Provides a custom annotation view for a given MKAnnotation object in an MKMapView.
    /// - Parameters:
    ///   - mapView: The MKMapView containing the annotation.
    ///   - annotation: The MKAnnotation object for which to provide a custom annotation view.
    /// - Returns: The custom MKAnnotationView object to be used for the given annotation.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // Create a new MKMarkerAnnotationView with a reuse identifier
        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "CLINICPIN")
        
        // Set the draggable property of the marker to true, allowing it to be dragged
        marker.isDraggable = true
        
        // Set the canShowCallout property of the marker to false, preventing the callout from being displayed
        marker.canShowCallout = false
        
        // Return the created marker as the custom annotation view
        return marker
    }

    
    /// Callback method that is called when the drag state of an MKAnnotationView changes.
    /// - Parameters:
    ///   - mapView: The MKMapView containing the annotation view.
    ///   - view: The MKAnnotationView whose drag state changed.
    ///   - newState: The new drag state of the annotation view.
    ///   - oldState: The old drag state of the annotation view.
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        //print("Updated")
        
        // Extract the new location coordinate from the annotation view
        guard let newLocation = view.annotation?.coordinate else { return }
        
        // Update the pickedLocation property with the new location coordinate
        self.pickedLocation = .init(latitude: newLocation.latitude, longitude: newLocation.longitude)
        
        // Call the updatePlacemark function to update the placemark information based on the new location
        updatePlacemark(location: .init(latitude: newLocation.latitude, longitude: newLocation.longitude))
    }
    
    /// Updates the CLPlacemark property `pickedPlaceMark` with the reverse geocoded placemark information for the given CLLocation object.
    /// - Parameters:
    ///   - location: The CLLocation object for which reverse geocoding needs to be performed.
    func updatePlacemark(location: CLLocation) {
        Task {
            do {
                // Perform reverse geocoding using the `reverseLocationCoordinates` function and await the result
                guard let place = try await reverseLocationCoordinates(location: location) else { return }
                
                // Update the `pickedPlaceMark` property on the main actor's queue
                await MainActor.run {
                    self.pickedPlaceMark = place
                }
            } catch {
                // Handle any errors that occur during reverse geocoding
            }
        }
    }
    
    /// Displaying New Location Data
    /// Reverse geocodes the given CLLocation object to obtain placemark information, and constructs a JSON payload
    /// containing relevant location data.
    /// - Parameters:
    ///   - location: The CLLocation object to be reverse geocoded.
    /// - Returns: A CLPlacemark object containing the reverse geocoded information, or nil if reverse geocoding fails.
    /// - Throws: An error if there is an issue with reverse geocoding.
    func reverseLocationCoordinates(location: CLLocation) async throws -> CLPlacemark? {
        let geocoder = CLGeocoder()
        
        // Perform reverse geocoding using the CLGeocoder's `reverseGeocodeLocation` method
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        let placemark = placemarks.first
        var payload: [String: String] = [:]
        
        if let placemark = placemarks.first {
            // Retrieve CLPlacemark information
            let locality = placemark.locality ?? ""
            let country = placemark.country ?? ""
            let name = placemark.name ?? ""
            let state = placemark.administrativeArea ?? ""
            let streetAddress = placemark.thoroughfare ?? ""
            let zipCode = placemark.postalCode ?? ""
            
            // Construct JSON payload
            payload = [
                "city": locality,
                "country": country,
                "name": name,
                "state": state,
                "streetAddress": streetAddress,
                "zipCode": zipCode
            ]
            // Set the payload as a property for future use
            self.finalPayload = payload
            print(payload)
        }
        
        return placemark
    }

}
