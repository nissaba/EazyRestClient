//
// EazyRestResponse.swift
//
// Generic API response for EazyREST framework
//
// Created and maintained by Pascale Beaulac
// Copyright © 2019–2025 Pascale Beaulac
//
// Licensed under the MIT License.
//

import Foundation

/// A generic top-level response wrapper for API requests in the EazyREST framework.
///
/// Use this structure to decode API responses that include a variety of metadata fields and a data payload.
/// The payload is generic and should match the expected Decodable type for your endpoint.
///
/// - Parameter Response: The expected Decodable type for the response's `data` field.
public struct EazyRestResponse<Response: Decodable>: Decodable {
    /// Optional status code returned by the API.
    public let code: Int?
    /// Optional additional details provided by the server, often used for validation errors.
    public let details: [String]?
    /// Optional error string, present when the response represents an error state.
    public let error: String?
    /// Optional human-readable message from the server, often accompanying errors or status updates.
    public let message: String?
    /// The decoded payload from the server response, matching the expected Decodable type.
    public let data: Response?
}
