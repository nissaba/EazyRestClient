/**
 EazyRestError.swift
 
 Defines all error types for the EazyRestClient, covering networking, response, decoding,
 and authorization issues that may occur during REST API interactions.
 
 - Author: Pascale Beaulac
 - Copyright: © 2019–2025 Pascale Beaulac
 - License: MIT
*/


import Foundation

/// Comprehensive error types for EazyRestClient, representing all failures that can occur across request, transport, response, and decoding phases.
public enum EazyRestError: Error, Equatable {
    case invalidURL
    case badResponse
    case serverError(Int)
    case decodingError(Error)
    case transportError(Error)
    case unauthorized
    case forbidden
    case notFound
    case timeout

    public static func ==(lhs: EazyRestError, rhs: EazyRestError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.badResponse, .badResponse): return true
        case let (.serverError(a), .serverError(b)): return a == b
        case let (.decodingError(a), .decodingError(b)): return type(of: a) == type(of: b)
        case let (.transportError(a), .transportError(b)): return type(of: a) == type(of: b)
        case (.unauthorized, .unauthorized): return true
        case (.forbidden, .forbidden): return true
        case (.notFound, .notFound): return true
        case (.timeout, .timeout): return true
        default: return false
        }
    }
}

extension EazyRestError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid."
        case .badResponse:
            return "Invalid or missing response."
        case .serverError(let code):
            return "Server returned status code \(code)."
        case .decodingError(let err):
            return "Decoding failed: \(err.localizedDescription)"
        case .transportError(let err):
            return "Network error: \(err.localizedDescription)"
        case .unauthorized:
            return "Unauthorized request. Authentication is required (401)."
        case .forbidden:
            return "Access forbidden. You do not have permission to access this resource (403)."
        case .notFound:
            return "Resource not found (404)."
        case .timeout:
            return "The request timed out."
        }
    }
}
