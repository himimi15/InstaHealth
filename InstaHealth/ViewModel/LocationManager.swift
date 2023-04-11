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
    
    override init() {
        super.init()
        // Setting Delegates
        manager.delegate = self
        mapView.delegate = self
        
        // requesting location access
        manager.requestWhenInUseAuthorization()
        
        // Search Textfield Watching
        cancellable = $searchText
            .debounce(for: .seconds(0.5), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink(receiveValue: { value in
                if value != ""{
                    self.fetchPlaces(value: value)
                }else{
                    self.fetchedPlaces = nil
                }
            })
    }
    
    func fetchPlaces(value: String) {
        // fetching places using MKLocalSearch
        Task{
            do{
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = value.lowercased()
                
                let response = try await MKLocalSearch(request: request).start()
                
                await MainActor.run(body: {
                    self.fetchedPlaces = response.mapItems.compactMap({ item -> CLPlacemark in
                        return item.placemark
                    })
                })
            }
            catch{
                // handles error
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
    
    // Location Authorization
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus{
        case .authorizedAlways: manager.requestLocation()
        case .authorizedWhenInUse: manager.requestLocation()
        case .denied: handleLocationError()
        case .notDetermined: manager.requestWhenInUseAuthorization()
        default: ()
        }
    }
    
    func handleLocationError(){
        // handles error
    }
    
    // Add Draggable Pin to MapView
    func addDraggablePin(coordinate: CLLocationCoordinate2D) {
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = "Clinic will be added here"
        
        mapView.addAnnotation(annotation)
    }
    
    // Enabling Dragging
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let marker = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "CLINICPIN")
        marker.isDraggable = true
        marker.canShowCallout = false
        
        return marker
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, didChange newState: MKAnnotationView.DragState, fromOldState oldState: MKAnnotationView.DragState) {
        //print("Updated")
        guard let newLocation = view.annotation?.coordinate else{return}
        self.pickedLocation = .init(latitude: newLocation.latitude, longitude: newLocation.longitude)
        updatePlacemark(location: .init(latitude: newLocation.latitude, longitude: newLocation.longitude))
    }
    
    //
    func updatePlacemark(location: CLLocation){
        Task{
            do{
                guard let place = try await reverseLocationCoordinates(location: location) else{return}
                await MainActor.run(body: {
                    self.pickedPlaceMark = place
                })
            }
            catch{
                
            }
        }
    }
    
    // Displaying New Location Data
    func reverseLocationCoordinates(location: CLLocation)async throws->CLPlacemark?{
        let geocoder = CLGeocoder()
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
            self.finalPayload = payload
            print(payload)
        }
        return placemark
    }
}
