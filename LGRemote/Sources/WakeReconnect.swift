import Foundation

// Only runs after an explicit wake request. No network discovery or repeating service.
@MainActor
enum WakeReconnect {
    static func run(
        wait: (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) },
        step: () -> Bool
    ) async throws -> Bool {
        for _ in 0..<8 {
            try await wait(5_000_000_000)
            try Task.checkCancellation()
            if step() { return true }
        }
        return false
    }
}
