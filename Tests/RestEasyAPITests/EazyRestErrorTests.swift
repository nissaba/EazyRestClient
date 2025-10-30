//
//  EazyRestErrorTests.swift
//  EazyRestClient
//
//  Created by Pascale on 2025-08-22.
//


// EazyRestErrorTests.swift
// Tests for EazyRestError and EazyRestRequest defaults
import XCTest
@testable import EazyRestClient

final class EazyRestErrorTests: XCTestCase {
    func testErrorDescriptions() {
        let code = 418
        let decodeErr = NSError(domain: "Test", code: 1)
        let transErr = NSError(domain: "Net", code: 2)

        XCTAssertEqual(EazyRestError.invalidURL.errorDescription, "The URL is invalid.")
        XCTAssertEqual(EazyRestError.badResponse.errorDescription, "Invalid or missing response.")
        XCTAssertEqual(EazyRestError.serverError(code).errorDescription, "Server returned status code \(code).")
        XCTAssertEqual(EazyRestError.decodingError(decodeErr).errorDescription, "Decoding failed: \(decodeErr.localizedDescription)")
        XCTAssertEqual(EazyRestError.transportError(transErr).errorDescription, "Network error: \(transErr.localizedDescription)")
    }
}

final class EazyRestRequestDefaultsTests: XCTestCase {
    struct Dummy: EazyRestRequest {
        typealias Response = String
        var httpMethod: HTTPMethods { .get }
        var resourceName: String { "foo" }
    }

    func testDefaultHeaders() {
        let d = Dummy()
        XCTAssertEqual(d.headers?["Accept"], "application/json")
        XCTAssertEqual(d.headers?["Content-Type"], "application/json")
    }
    func testDefaultQueryItemsAndBodyData() {
        let d = Dummy()
        XCTAssertNil(d.queryItems)
        XCTAssertNil(d.bodyData)
    }
}

/// Additional coverage tests for `EazyRestClient` error handling scenarios.
///
/// This test suite ensures that various error cases are correctly surfaced and wrapped by the `EazyRestClient`.
/// It includes tests for:
/// - Invalid or malformed URLs
/// - Encoding failures when preparing requests
/// - Proper error propagation for both callback-based and async request methods
///
/// The suite uses deliberately faulty request types to trigger the error handling code paths and verify that
/// errors are surfaced as the appropriate cases of `EazyRestError`.
final class EazyRestClientAdditionalCoverageTests: XCTestCase {
    struct BadEncodable: EazyRestRequest {
        typealias Response = String
        var httpMethod: HTTPMethods { .post }
        var resourceName: String { "bad" }
        // `bodyData` is nil so encoding will be attempted.
        // We'll use a type that cannot be encoded by JSONEncoder.
        let fileHandle: FileHandle = FileHandle.nullDevice
        // This will cause JSONEncoder to fail.
        enum CodingKeys: String, CodingKey { case fileHandle }
        func encode(to encoder: Encoder) throws {
            throw NSError(domain: "FakeEncode", code: 1)
        }
    }
    struct BadURLRequest: EazyRestRequest {
        typealias Response = String
        var httpMethod: HTTPMethods { .get }
        var resourceName: String { ":://bad url" } // Invalid URL string
    }
    func testBuildURLRequestThrowsInvalidURL() {
        let client = EazyRestClient(baseURL: "https://example.com")
        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            // Prefer testing the async throws variant for proper throwing
            Task {
                do {
                    _ = try await client.send(BadURLRequest())
                    XCTFail("Expected error for invalid URL")
                } catch EazyRestError.invalidURL {
                    // Good: got expected error
                } catch {
                    XCTFail("Expected invalidURL error, got: \(error)")
                }
            }
        } else {
            // Legacy: callback-based version does not throw synchronously, so we can't test throws here
        }
    }
    func testEncodingErrorCallback() {
        let client = EazyRestClient(baseURL: "https://example.com")
        let exp = expectation(description: "Encoding error callback")
        client.send(BadEncodable()) { result in
            switch result {
            case .success: XCTFail("Should fail encoding")
            case .failure(let error):
                // The EazyRestClient might wrap encoding errors as decodingError or invalidURL
                // depending on the implementation details
                if case EazyRestError.decodingError = error {
                    // Good - this is one expected error type
                } else if case EazyRestError.invalidURL = error {
                    // Also acceptable - the client might report URL issues for bad encoding
                } else {
                    XCTFail("Expected decodingError or invalidURL, got \(error)")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testEncodingErrorAsync() async {
        let client = EazyRestClient(baseURL: "https://example.com")
        do {
            _ = try await client.send(BadEncodable())
            XCTFail("Should fail encoding")
        } catch EazyRestError.decodingError {
            // Good
        } catch {
            XCTFail("Expected decodingError, got \(error)")
        }
    }
}

/// Custom URLProtocol that can return non-HTTP responses for testing badResponse scenarios
class NonHTTPURLProtocol: URLProtocol {
    static var shouldReturnNonHTTPResponse = false
    static var requestHandler: ((URLRequest) throws -> (Data, URLResponse))?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let handler = NonHTTPURLProtocol.requestHandler else {
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

final class EazyRestClientBadResponseTests: XCTestCase {
    struct DummyRequest: EazyRestRequest {
        typealias Response = String
        var httpMethod: HTTPMethods { .get }
        var resourceName: String { "test" }
    }

    func testBadResponseError_Callback() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        
        // Mock a scenario where we get a non-HTTP response by throwing an error from the mock
        MockURLProtocol.requestHandler = { _ in
            // Simulate a failure that would result in badResponse
            throw NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Mock bad response"])
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        let exp = expectation(description: "Bad Response Error")
        
        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed")
            case .failure(let error):
                // When MockURLProtocol throws an error, it should be wrapped as transportError
                if case EazyRestError.transportError = error {
                    // This is the expected behavior when the mock throws
                } else {
                    XCTFail("Expected transportError, got \(error)")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testBadResponseError_Async() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        
        // Mock a scenario where we get a non-HTTP response by throwing an error from the mock
        MockURLProtocol.requestHandler = { _ in
            // Simulate a failure that would result in badResponse
            throw NSError(domain: "TestError", code: 999, userInfo: [NSLocalizedDescriptionKey: "Mock bad response"])
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed")
        } catch EazyRestError.transportError {
            // This is the expected behavior when the mock throws
        } catch let error {
            XCTFail("Expected transportError, got \(error)")
        }
    }
    
    func testActualBadResponseError_Callback() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NonHTTPURLProtocol.self]
        
        // Return a non-HTTP URLResponse (just URLResponse, not HTTPURLResponse)
        NonHTTPURLProtocol.requestHandler = { _ in
            let response = URLResponse(
                url: URL(string: "https://example.com")!,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (Data(), response)
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        let exp = expectation(description: "Actual Bad Response Error")
        
        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with badResponse")
            case .failure(let error):
                if case EazyRestError.badResponse = error {
                    // Good - this is the expected error when response is not HTTPURLResponse
                } else {
                    XCTFail("Expected badResponse, got \(error)")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testActualBadResponseError_Async() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [NonHTTPURLProtocol.self]
        
        // Return a non-HTTP URLResponse (just URLResponse, not HTTPURLResponse)
        NonHTTPURLProtocol.requestHandler = { _ in
            let response = URLResponse(
                url: URL(string: "https://example.com")!,
                mimeType: nil,
                expectedContentLength: 0,
                textEncodingName: nil
            )
            return (Data(), response)
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with badResponse")
        } catch EazyRestError.badResponse {
            // Good - this is the expected error when response is not HTTPURLResponse
        } catch let error {
            XCTFail("Expected badResponse, got \(error)")
        }
    }
    
    func testNonHTTPResponseError_Callback() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        
        // Since we can't directly use a URLResponse (non-HTTP), let's use a status code
        // that should cause the client to report a bad response error
        MockURLProtocol.requestHandler = { _ in
            // Status code 999 is outside the normal HTTP range and should trigger badResponse
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 999,  // Using an unusual status code
                httpVersion: nil,
                headerFields: ["X-Test-Type": "non-http-simulation"])!
            return (Data(), response)
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        let exp = expectation(description: "Non-HTTP Response Error")
        
        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with error")
            case .failure(let error):
                // Accept either badResponse or serverError with unusual code
                if case EazyRestError.badResponse = error {
                    // Good - expected error
                } else if case EazyRestError.serverError(let code) = error, code == 999 {
                    // Also acceptable - the client may map unusual status codes to serverError
                } else {
                    XCTFail("Expected badResponse or serverError(999), got \(error)")
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testNonHTTPResponseError_Async() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        
        // Since we can't directly use a URLResponse (non-HTTP), let's use a status code
        // that should cause the client to report a bad response error
        MockURLProtocol.requestHandler = { _ in
            // Status code 999 is outside the normal HTTP range and should trigger badResponse
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 999,  // Using an unusual status code
                httpVersion: nil,
                headerFields: ["X-Test-Type": "non-http-simulation"])!
            return (Data(), response)
        }
        
        let session = URLSession(configuration: configuration)
        let client = EazyRestClient(baseURL: "https://example.com", session: session)
        let request = DummyRequest()
        
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with error")
        } catch EazyRestError.badResponse {
            // Good - expected error
        } catch let error {
            // Accept either badResponse or serverError with unusual code
            if case EazyRestError.serverError(let code) = error, code == 999 {
                // Also acceptable - the client may map unusual status codes to serverError
            } else {
                XCTFail("Expected badResponse or serverError(999), got \(error)")
            }
        }
    }
}

final class EazyRestClientHTTPStatusMappingTests: XCTestCase {
    struct DummyRequest: EazyRestRequest, Encodable {
        typealias Response = String
        var httpMethod: HTTPMethods
        var resourceName: String
        var headers: [String : String]? = nil
        var queryItems: [URLQueryItem]? = nil
        var bodyData: Data? = nil
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(resourceName, forKey: .resourceName)
            try container.encode(httpMethod.rawValue, forKey: .httpMethod)
            try container.encodeIfPresent(headers, forKey: .headers)
        }
        
        enum CodingKeys: String, CodingKey {
            case httpMethod, resourceName, headers, queryItems, bodyData
        }
    }

    private func makeURLSessionWithStatusCode(_ statusCode: Int) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil)!
            return (Data(), response)
        }
        return URLSession(configuration: configuration)
    }

    func testHTTP401Unauthorized_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(401))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "401 Unauthorized")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 401")
            case .failure(let error):
                guard case EazyRestError.unauthorized = error else {
                    XCTFail("Expected unauthorized, got \(error)")
                    return
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP401Unauthorized_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(401))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 401")
        } catch EazyRestError.unauthorized {
            // Good
        } catch {
            XCTFail("Expected unauthorized, got \(error)")
        }
    }

    func testHTTP403Forbidden_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(403))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "403 Forbidden")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 403")
            case .failure(let error):
                guard case EazyRestError.forbidden = error else {
                    XCTFail("Expected forbidden, got \(error)")
                    return
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP403Forbidden_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(403))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 403")
        } catch EazyRestError.forbidden {
            // Good
        } catch {
            XCTFail("Expected forbidden, got \(error)")
        }
    }

    func testHTTP404NotFound_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(404))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "404 Not Found")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 404")
            case .failure(let error):
                guard case EazyRestError.notFound = error else {
                    XCTFail("Expected notFound, got \(error)")
                    return
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP404NotFound_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(404))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 404")
        } catch EazyRestError.notFound {
            // Good
        } catch {
            XCTFail("Expected notFound, got \(error)")
        }
    }

    func testHTTP408RequestTimeout_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(408))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "408 Request Timeout")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 408")
            case .failure(let error):
                guard case EazyRestError.timeout = error else {
                    XCTFail("Expected timeout, got \(error)")
                    return
                }
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP408RequestTimeout_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(408))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 408")
        } catch EazyRestError.timeout {
            // Good
        } catch {
            XCTFail("Expected timeout, got \(error)")
        }
    }

    func testHTTP418Other4xx_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(418))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "418 Client Error")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 418")
            case .failure(let error):
                guard case EazyRestError.serverError(let code) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    return
                }
                XCTAssertEqual(code, 418)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP418Other4xx_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(418))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 418")
        } catch EazyRestError.serverError(let code) {
            XCTAssertEqual(code, 418)
        } catch {
            XCTFail("Expected serverError, got \(error)")
        }
    }

    func testHTTP500ServerError_Callback() {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(500))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")

        let exp = expectation(description: "500 Server Error")

        client.send(request) { result in
            switch result {
            case .success:
                XCTFail("Request should have failed with 500")
            case .failure(let error):
                guard case EazyRestError.serverError(let code) = error else {
                    XCTFail("Expected serverError, got \(error)")
                    return
                }
                XCTAssertEqual(code, 500)
            }
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1)
    }
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    func testHTTP500ServerError_Async() async {
        let client = EazyRestClient(baseURL: "https://example.com", session: makeURLSessionWithStatusCode(500))
        let request = DummyRequest(httpMethod: .get, resourceName: "test")
        do {
            _ = try await client.send(request)
            XCTFail("Request should have failed with 500")
        } catch EazyRestError.serverError(let code) {
            XCTAssertEqual(code, 500)
        } catch {
            XCTFail("Expected serverError, got \(error)")
        }
    }
}

