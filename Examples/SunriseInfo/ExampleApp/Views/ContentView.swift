//
//  ContentView.swift
//  ExampleApp
//
//  Created by Pascale on 2025-04-28.
//

import SwiftUI
import EazyRestClient
import CoreLocation


struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @State private var sunrise: String = "-"
    @State private var sunset: String = "-"
    @State private var errorMessage: String?

    private let apiClient = RestEasyAPI(baseUrl: "https://api.sunrise-sunset.org/")

    var body: some View {
        VStack(spacing: 20) {
            Text("Sunrise: \(sunrise)")
            Text("Sunset: \(sunset)")
            
            if let errorMessage = errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
            }

            Button("Fetch Sunrise/Sunset") {
                fetchSunTimes()
            }
        }
        .padding()
    }
    
    @MainActor
    func updateView(with result: Result<SunriseSunsetResponse, Error>) {
        switch result {
        case .success(let response):
            sunrise = convertISOToLocal(response.results.sunrise)
            sunset = convertISOToLocal(response.results.sunset)
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }
    
    func convertISOToLocal(_ isoString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = isoFormatter.date(from: isoString) else {
            return isoString
        }

        let localFormatter = DateFormatter()
        localFormatter.timeZone = TimeZone.current
        localFormatter.dateFormat = "HH:mm"

        return localFormatter.string(from: date)
    }





    private func fetchSunTimes() {
        guard let location = locationManager.lastKnownLocation else {
            errorMessage = "Location not available yet."
            return
        }
        
        let request = GetSunriseSunsetRequest(
            latitude: location.latitude,
            longitude: location.longitude,
            tzid: TimeZone.current.identifier  // Ex: "America/Toronto"
        )

        apiClient.send(request) { result in
            Task { @MainActor in
                updateView(with: result)
            }
        }
    }
}
