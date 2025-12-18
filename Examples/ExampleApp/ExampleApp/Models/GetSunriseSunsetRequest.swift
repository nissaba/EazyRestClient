//
//  GetSunriseSunsetRequest.swift
//  ExampleApp
//
//  Created by Pascale on 2025-04-28.
//

import Foundation
import EazyRestClient

/// Request for Sunrise-Sunset API
struct GetSunriseSunsetRequest: EazyRestRequest {
    
    var bodyData: Data?
    
    typealias Response = SunriseSunsetResponse

    let latitude: Double
    let longitude: Double
    let tzid: String  // ex: "America/Toronto"

    var httpMethod: HTTPMethods { .get }
    var resourceName: String { "json" }

    var queryItems: [URLQueryItem]? {
        [
            URLQueryItem(name: "lat", value: "\(latitude)"),
            URLQueryItem(name: "lng", value: "\(longitude)"),
            URLQueryItem(name: "tzid", value: tzid)
        ]
    }
}
