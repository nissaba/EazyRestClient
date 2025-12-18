//
//  EazyRestRequest+defaults.swift
//  EazyRestClient
//
//  Created by Pascale on 2025-04-29.
//

import Foundation

/// Default implementations for optional properties on EazyRestRequest
public extension EazyRestRequest {
    /// Default HTTP headers for all requests
    /// - Accept: application/json
    /// - Content-Type: application/json
    var headers: [String: String]? {
        [
            "Accept": "application/json",
            "Content-Type": "application/json"
        ]
    }

    /// Default query items (none)
    var queryItems: [URLQueryItem]? {
        nil
    }

    /// Default body data (none)
    var bodyData: Data? {
        nil
    }
}
