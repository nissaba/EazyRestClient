import Foundation

/// Minimal lock-protected container for shared mutable state in tests.
///
/// Swift 6 strict concurrency flags `static var` shared state as unsafe.
/// This wrapper keeps the shared reference immutable (`static let`) while
/// protecting the underlying value with a lock.
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}

