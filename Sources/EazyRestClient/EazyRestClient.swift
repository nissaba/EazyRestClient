///
/// EazyRestClient
///
/// A lightweight, protocol-oriented HTTP client for making REST API calls.
/// Supports both callback-based and async/await APIs (async/await requires iOS 15+/macOS 12+/tvOS 15+/watchOS 8+).
///
/// Usage:
/// ```swift
/// let client = EazyRestClient(baseURL: "https://api.example.com/")
/// client.authToken = "Bearer token"
///
/// // Callback version:
/// client.send(MyRequest()) { result in
///     switch result {
///     case .success(let response): print(response)
///     case .failure(let error): print(error)
///     }
/// }
///
/// // Async/Await version (iOS 15+, macOS 12+):
/// Task {
///     do {
///         let response = try await client.send(MyRequest())
///         print(response)
///     } catch {
///         print(error)
///     }
/// }
/// ```

import Foundation

/// Typealias for callback-based completion handlers.
public typealias ResultCallback<T> = @Sendable (Result<T, Error>) -> Void

/// Main HTTP client class for EazyRestClient.
/// Handles request building, header injection, and response decoding.
public actor EazyRestClient {
    private let session: URLSession
    private let baseURL: URL

    /// Optional Authorization token. If set, added as `Authorization` header.
    public var authToken: String?

    /// Initializes the HTTP client with a base URL string and optional URLSession.
    /// - Parameters:
    ///   - baseURL: The root endpoint for all requests (e.g. "https://api.example.com/").
    ///   - session: URLSession instance to use; defaults to `URLSession.shared`.
    public init(baseURL: String, session: URLSession = .shared) {
        guard let url = URL(string: baseURL) else {
            fatalError("Invalid base URL: \(baseURL)")
        }
        self.baseURL = url
        self.session = session
    }

    // MARK: - Callback version (iOS 13+ / macOS 10.15+)

    /// Sends a `EazyRestRequest` using a callback-based API.
    /// - Parameters:
    ///   - request: An object conforming to `EazyRestRequest`.
    ///   - completion: Closure called on the main thread with a `Result` of decoded response or error.
    public func send<Request: EazyRestRequest>(
        _ request: Request,
        completion: @escaping ResultCallback<Request.Response>
    ) {
        Task {
            do {
                let response = try await self.send(request)
                await MainActor.run {
                    completion(.success(response))
                }
            } catch {
                await MainActor.run {
                    if let restError = error as? EazyRestError {
                        completion(.failure(restError))
                    } else {
                        completion(.failure(EazyRestError.transportError(error)))
                    }
                }
            }
        }
    }

    // MARK: - Async/Await version (iOS 15+ / macOS 12+ / tvOS 15+ / watchOS 8+)

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    /// Sends a `EazyRestRequest` using Swift concurrency (`async/await`).
    /// - Parameter request: An object conforming to `EazyRestRequest`.
    /// - Returns: The decoded response of type `Request.Response`.
    /// - Throws: `EazyRestError` on failure.
    public func send<Request: EazyRestRequest>(
        _ request: Request
    ) async throws -> Request.Response {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildURLRequest(for: request)
        } catch let error as EazyRestError {
            throw error
        } catch {
            throw EazyRestError.invalidURL
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw EazyRestError.transportError(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw EazyRestError.badResponse
        }

        if !(200..<300).contains(http.statusCode) {
            switch http.statusCode {
            case 401:
                throw EazyRestError.unauthorized
            case 403:
                throw EazyRestError.forbidden
            case 404:
                throw EazyRestError.notFound
            case 408:
                throw EazyRestError.timeout
            case 400..<600:
                throw EazyRestError.serverError(http.statusCode)
            default:
                throw EazyRestError.serverError(http.statusCode)
            }
        }

        do {
            return try JSONDecoder().decode(Request.Response.self, from: data)
        } catch {
            throw EazyRestError.decodingError(error)
        }
    }

    // MARK: - Request builder

    /// Internal helper to construct a `URLRequest` from a `EazyRestRequest`.
    /// - Parameter request: The request object containing resource, query items, headers, and body data.
    /// - Returns: A configured `URLRequest`.
    /// - Throws: `EazyRestError.invalidURL` if the URL is invalid or cannot be constructed.
    private func buildURLRequest<Request: EazyRestRequest>(
        for request: Request
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(request.resourceName),
            resolvingAgainstBaseURL: true
        ) else {
            throw EazyRestError.invalidURL
        }
        if let items = request.queryItems {
            components.queryItems = items
        }
        guard let url = components.url else {
            throw EazyRestError.invalidURL
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.httpMethod.rawValue
        urlRequest.httpShouldHandleCookies = false

        if let token = authToken {
            urlRequest.addValue(token, forHTTPHeaderField: "Authorization")
        }
        request.headers?.forEach { key, val in
            urlRequest.setValue(val, forHTTPHeaderField: key)
        }

        if let body = request.bodyData {
            urlRequest.httpBody = body
        } else if request.httpMethod == .post || request.httpMethod == .put {
            do {
                urlRequest.httpBody = try JSONEncoder().encode(request)
                if urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
                    urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            } catch {
                throw EazyRestError.decodingError(error)
            }
        }

        return urlRequest
    }
}

