//
// EazyResRequest.swift
//
// Request protocol for EazyREST framework
//
// Created and maintained by Pascale Beaulac
// Copyright © 2019–2025 Pascale Beaulac
//
// Licensed under the MIT License.
//

import Foundation

/// A protocol representing a REST request in the EazyREST framework.
///
/// Types conforming to `EazyRestRequest` define all information needed to perform a RESTful network request,
/// including HTTP method, resource path, headers, query items, and body data. The associated `Response` type
/// specifies the expected response model for this request.
///
/// Conforming types must provide:
/// - `httpMethod`: The HTTP method to use (GET, POST, etc.).
/// - `resourceName`: The resource path relative to the base URL.
/// - `headers`: Optional HTTP headers (default is JSON if not specified).
/// - `queryItems`: Optional URL query parameters (commonly for GET requests).
/// - `bodyData`: Optional raw body data to override the Encodable body.
///
/// The protocol ensures a consistent structure for building, encoding, and sending requests within EazyREST.
public protocol EazyRestRequest: Encodable, Sendable {
    associatedtype Response: Decodable & Sendable
    
    /// HTTP method (GET, POST, PUT, DELETE, etc.)
    var httpMethod: HTTPMethods { get }
    
    /// Resource path relative to base URL.
    var resourceName: String { get }
    
    /// Headers (default: JSON unless overridden).
    var headers: [String: String]? { get }
    
    /// Optional Query Items (for GET requests typically).
    var queryItems: [URLQueryItem]? { get }
    
    /// Body Data (optional, overrides Encodable body if provided).
    var bodyData: Data? { get }
}
