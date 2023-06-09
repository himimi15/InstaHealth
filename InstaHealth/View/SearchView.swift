//
//  SearchView.swift
//  InstaHealth
//
//  Created by Michael Law on 4/10/23.
//

import SwiftUI
import MapKit
import Foundation

struct SearchView: View {
    @StateObject var locationManager: LocationManager = .init()
    // Location manager state object to handle location-related functionality
    @State var navigationTag: String?   // navigation tag to push view to mapview
    
    var body: some View {
        VStack{
            HStack(spacing: 15) {
                
                Text("Search Location") // Title for the search view
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity,alignment: .leading)
            
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")    // Magnifying glass icon
                    .foregroundColor(.gray)
                
                TextField("Find locations here", text: $locationManager.searchText)
            }
            .padding(.vertical,12)
            .padding(.horizontal)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.gray)
            }
            .padding(.vertical,10)
            
            if let places = locationManager.fetchedPlaces,!places.isEmpty{
                List {
                    ForEach(places, id: \.self) {place in
                        Button {
                            if let coordinate = place.location?.coordinate{
                                // Update pickedLocation in the location manager
                                locationManager.pickedLocation = .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
                                // Update map region to show selected location
                                locationManager.mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                                // Add draggable pin on the map
                                locationManager.addDraggablePin(coordinate: coordinate)
                                // Update placemark information for the selected location
                                locationManager.updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
                            }
                            
                            // Trigger navigation to MapView
                            navigationTag = "MAPVIEW"
                            
                        } label: {
                            HStack(spacing: 15){
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(place.name ?? "")
                                        .font(.title3.bold())
                                        .foregroundColor(.primary)
                                    
                                    Text(place.locality ?? "")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
            else {
                // Live Location Button
                Button {
                    // setting map region
                    if let coordinate = locationManager.userLocation?.coordinate{
                        locationManager.mapView.region = .init(center: coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
                        locationManager.addDraggablePin(coordinate: coordinate)
                        locationManager.updatePlacemark(location: .init(latitude: coordinate.latitude, longitude: coordinate.longitude))
                        
                        // navigating to MapView
                        navigationTag = "MAPVIEW"
                    }
                    
                } label: {
                    Label {
                        Text("Use Current Location")
                            .font(.callout)
                    } icon: {
                        Image(systemName: "location.north.circle.fill")
                    }
                    .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity,alignment: .leading)
            }
        }
        .padding()
        .frame(maxHeight: .infinity,alignment: .top)
        .background{
            NavigationLink(tag: "MAPVIEW", selection: $navigationTag) {
                MapViewSelection()
                    .environmentObject(locationManager)
                    .navigationBarHidden(true)
            } label: {}
                .labelsHidden()
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView()
    }
}

// MapView Live Selection
struct MapViewSelection: View{
    // The LocationManager object that manages location-related functionalities in the app.
    @EnvironmentObject var locationManager: LocationManager
    // The dismiss action to dismiss the current view, retrieved from the environment.
    @Environment(\.dismiss) var dismiss
    
    var body: some View{
        ZStack{
            MapViewHelper()
            // Passes the locationManager object to the MapViewHelper view as an environment object
                .environmentObject(locationManager) 
                .ignoresSafeArea()
            
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                 
            }
            .padding()
            .frame(maxWidth: .infinity,maxHeight: .infinity,alignment: .topLeading)
            
            // Displaying Data
            if let place = locationManager.pickedPlaceMark{
                VStack(spacing: 15){
                    Text("Add Your Clinic")
                        .font(.title2.bold())
                    
                    HStack(spacing: 15){
                        Image(systemName: "mappin.circle.fill")
                            .font(.title2)
                            .foregroundColor(.gray)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text(place.name ?? "")
                                .font(.title3.bold())
                            
                            Text(place.locality ?? "")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .frame(maxWidth: .infinity,alignment: .leading)
                    .padding(.vertical,10)
                    
                    // A button that triggers a function to send a POST request with the selected place data when tapped
                    Button {
                        let payload = locationManager.finalPayload
                        sendPOSTRequest(payload: payload)
                        // Calls a function to send a POST request with the payload data.
                    } label: {
                        Text("Add Your Clinic")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical,12)
                            .background{
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(.green)
                            }
                            .overlay(alignment: .trailing){
                                Image(systemName: "arrow.right")
                                    .font(.title3.bold())
                                    .padding(.trailing)
                            }
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background{
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.white)
                        .ignoresSafeArea()
                }
                .frame(maxHeight: .infinity,alignment: .bottom)
            }
        }
        .onDisappear{
            locationManager.pickedLocation = nil
            locationManager.pickedPlaceMark = nil
            
            locationManager.mapView.removeAnnotations(locationManager.mapView.annotations)
        }
    }
}

// UIKit MapView
struct MapViewHelper: UIViewRepresentable{
    @EnvironmentObject var locationManager: LocationManager
    func makeUIView(context: Context) -> MKMapView {
        return locationManager.mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {}
}

/// Sends a POST request with the given payload to the specified URL.
/// - Parameters:
///   - payload: The payload to be sent as JSON data in the request body. Can be nil.
func sendPOSTRequest(payload: [String: String]?) {
    let urlString = "https://sandbox.demo.sainahealth.com/api/HealthProviders/CreateHealthProvider"
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("text/plain", forHTTPHeaderField: "accept")
    request.setValue("application/json-patch+json", forHTTPHeaderField: "Content-Type")
    
    do {
        // Serialize the payload as JSON data
        let jsonData = try JSONSerialization.data(withJSONObject: payload ?? [:], options: .prettyPrinted)
        request.httpBody = jsonData
    } catch {
        print("Error serializing payload: \(error.localizedDescription)")
        return
    }
    
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }
        
        if let data = data {
            // Try to parse the response data as JSON
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print("Response: \(json)")
            } else {
                // If not valid JSON, print the response as a string
                let responseString = String(data: data, encoding: .utf8)
                print("Response: \(responseString ?? "")")
            }
        }
    }
    task.resume()
}

// test POST request
/*
func sendGETRequest() {
    let urlString = "https://sandbox.demo.sainahealth.com/api/DDLServices/GetStates"
    let url = URL(string: urlString)!
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.addValue("text/plain", forHTTPHeaderField: "accept")
    
    // Send the request and handle the response
    let task = URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error sending request: \(error.localizedDescription)")
            return
        }
        
        if let data = data {
            if let responseString = String(data: data, encoding: .utf8) {
                print("Response: \(responseString)")
            }
        }
    }
    task.resume()
}
*/
