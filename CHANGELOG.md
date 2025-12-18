# Changelog

All notable changes to **EazyRestClient** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]
- Swift tools updated to 6.2
- `EazyRestRequest.Response` now requires `Sendable` for Swift 6 strict concurrency

## [1.1.0] - 2025-04-29
### Added
- Async/Await support with back-deployed Swift Concurrency for iOS 13+ / macOS 10.15+ (async API)
- Unit tests covering callback and async methods using `MockURLProtocol`
- GitHub Actions workflow for automatic `swift test` on push/PR
- Default HTTP headers (`Accept`, `Content-Type`) via `EazyRestRequest` extension
- Example code for both callback and async/await usage in README

### Changed
- Renamed project and module from `RestEasyAPI` to `EazyRestClient`
- Updated README with new installation URL and badges (SwiftPM, Platforms, Swift version, Tests, Release)
- Consolidated request building logic and improved error handling (`EazyRestError` enhancements)

## [1.0.0] - 2025-04-28
### Added
- Initial release of REST client supporting GET, POST, PUT, DELETE
- Protocol-oriented design with `EazyRestRequest`, `HTTPMethods`, and default implementations
- Callback-based API for iOS 13+ / macOS 10.15+
- Basic README and example app demonstrating callback usage


[Unreleased]: https://github.com/nissaba/EasyRestClient/compare/v1.1.0...HEAD
[1.1.0]: https://github.com/nissaba/EasyRestClient/releases/tag/v1.1.0
[1.0.0]: https://github.com/nissaba/EasyRestClient/releases/tag/v1.0.0
