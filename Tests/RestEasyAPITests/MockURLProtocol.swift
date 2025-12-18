//
//  MockURLProtocol.swift
//  EazyRestClient
//
//  Created by Pascale on 2025-04-29.
//


//
//  EazyRestClientTests.swift
//  EazyRestClientTests
//
//  Created by Pascale on 2025-04-29.
//

import XCTest
@testable import EazyRestClient

/// URLProtocol stub to intercept network calls and return custom responses.
class MockURLProtocol: URLProtocol {
    private struct State {
        var requestHandler: ((URLRequest) throws -> (Data, HTTPURLResponse))?
    }

    private static let state = Locked(State())

    /// Handler to be set in tests to return data, response or throw error.
    static var requestHandler: ((URLRequest) throws -> (Data, HTTPURLResponse))? {
        get { state.withLock { $0.requestHandler } }
        set { state.withLock { $0.requestHandler = newValue } }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        // Intercept all requests
        return true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            fatalError("Handler not set.")
        }

        do {
            let (data, response) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {
        // Required override. No cleanup needed.
    }
}


/// Unit tests for EazyRestClient covering success, error handling, and decoding scenarios.
///
/// Tests both callback and async/await APIs. Uses MockURLProtocol to stub network responses.
final class EazyRestClientTests: XCTestCase {
    var client: EazyRestClient!

    override func setUp() {
        super.setUp()
        // Configure URLSession to use MockURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        client = EazyRestClient(baseURL: "https://example.com", session: session)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        client = nil
        super.tearDown()
    }
     
    /// Simple codable struct used as a test response payload.
    struct TestResponse: Codable, Sendable {
        let value: String
    }

    /// Dummy request conforming to EazyRestRequest for testing various scenarios.
    struct DummyRequest: EazyRestRequest {
        typealias Response = TestResponse
        var httpMethod: HTTPMethods { .get }
        var resourceName: String { "path" }
        // `queryItems` and `bodyData` use the protocol’s default implementations
    }
    
    /// Tests that a successful response with valid data triggers the success callback and returns expected data.
    func testSuccessCallback() {
        // Prepare mock to return valid JSON and HTTP 200
        let expected = TestResponse(value: "hello")
        let jsonData = try! JSONEncoder().encode(expected)
        let url = URL(string: "https://example.com/path")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url, url)
            return (jsonData, response)
        }

        let exp = expectation(description: "Callback completes")
        client.send(DummyRequest()) { result in
            switch result {
            case .success(let resp):
                XCTAssertEqual(resp.value, "hello")
            case .failure(let error):
                XCTFail("Expected success, got error: \(error)")
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }

    /// Tests that a successful async response returns expected data using async/await version.
    /// Only runs on platforms supporting concurrency.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testSuccessAsync() async throws {
        let expected = TestResponse(value: "async")
        let data = try JSONEncoder().encode(expected)
        let url = URL(string: "https://example.com/path")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
        MockURLProtocol.requestHandler = { _ in (data, response) }

        let resp = try await client.send(DummyRequest())
        XCTAssertEqual(resp.value, "async")
    }
}
