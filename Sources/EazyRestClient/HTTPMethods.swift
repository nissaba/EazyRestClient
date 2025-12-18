//
//  HTTPMethods.swift
//  PatsRestService
//
//
// Created and maintained by Pascale Beaulac
// Copyright © 2019–2025 Pascale Beaulac
//
// Licensed under the MIT License.
//

/// Represents standard HTTP methods for network requests.
///
/// This enum provides cases for the most common HTTP methods used in RESTful communication:
/// - `get`: Retrieve data from a server.
/// - `post`: Send data to a server to create a resource.
/// - `put`: Replace a resource on the server.
/// - `delete`: Remove a resource from the server.
/// - `patch`: Partially update a resource on the server.
/// - `head`: Retrieve response headers identical to a GET request, but without the response body.
/// - `options`: Describe the communication options for the target resource.
public enum HTTPMethods: String {
    case get     = "GET"
    case post    = "POST"
    case put     = "PUT"
    case delete  = "DELETE"
    case patch   = "PATCH"
    case head    = "HEAD"
    case options = "OPTIONS"
}

