# EazyRestClient

![SwiftPM](https://img.shields.io/badge/SPM-Compatible-brightgreen.svg) ![Platform](https://img.shields.io/badge/platform-iOS%2013%20%7C%20macOS%2010.15%20%7C%20tvOS%2015%20%7C%20watchOS%208-blue) ![Swift](https://img.shields.io/badge/swift-6.2-orange.svg) ![Tests](https://github.com/nissaba/EazyRestClient/actions/workflows/tests.yml/badge.svg) ![Release](https://img.shields.io/github/v/release/nissaba/EazyRestClient)

## Features

- Protocol-based requests with `EazyRestRequest`
- Codable support for automatic encoding/decoding
- Default headers (`Accept` & `Content-Type`)
- Optional authorization token
- Query parameters and body data support
- URLSession under the hood
- Callback and Swift Concurrency (`async/await`) APIs

## Installation

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/nissaba/EazyRestClient.git", from: "1.1.0")
```

## Usage

### 1. Initialize the Client

```swift
import EazyRestClient

let client = EazyRestClient(baseURL: "https://api.example.com/")
// Optional authorization
client.authToken = "Bearer <token>"
```

### 2. Define a Request

```swift
struct MyRequest: EazyRestRequest {
    typealias Response = MyResponseModel

    var httpMethod: HTTPMethods { .get }
    var resourceName: String { "endpoint" }
    // Optionally override queryItems or bodyData
}
```

`Response` must conform to `Decodable` and `Sendable` (Swift 6 strict concurrency).

### 3. Callback-based Response Handling

```swift
client.send(MyRequest()) { result in
    switch result {
    case .success(let response):
        print(response)
    case .failure(let error):
        print("Error: \(error.localizedDescription)")
    }
}
```

### Or Async/Await Response Handling

```swift
// Requires iOS 15.0+, macOS 12.0+, tvOS 15.0+, watchOS 8.0+, visionOS 1.0+
Task {
    do {
        let response = try await client.send(MyRequest())
        print(response)
    } catch {
        print("Error: \(error.localizedDescription)")
    }
}
```

## Custom and Default Headers

By default, all requests include these HTTP headers:

```http
Accept: application/json
Content-Type: application/json
```

Override in a specific request if needed:

```swift
public extension MyCustomRequest: EazyRestRequest {
    var headers: [String: String]? {
        [
            "Accept": "application/json",
            "Authorization": "Bearer \(token)"
        ]
    }
}
```

## Example App

An **ExampleApp** demonstrating both callback and async/await usage is located in the `Examples/` folder. Open `ExampleApp.xcodeproj` and run on your device or simulator.

## License

MIT License. © 2025 Pascale Beaulac
