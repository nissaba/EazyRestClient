//
// Decodable+EazyRest.swift
//
// Utility extensions for EazyREST framework
//
// Created and maintained by Pascale Beaulac
// Copyright © 2019–2025 Pascale Beaulac
//
// Licensed under the MIT License.
//

import Foundation

public extension Decodable {
    /// Helper to decode a model from raw Data.
    static func decode(from data: Data) throws -> Self {
        return try JSONDecoder().decode(Self.self, from: data)
    }
}
