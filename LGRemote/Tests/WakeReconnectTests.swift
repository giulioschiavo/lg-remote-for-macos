import Foundation

@main struct WakeReconnectTests {
    @MainActor static func main() async throws {
        var waits: [UInt64] = [], attempts = 0
        let success = try await WakeReconnect.run(wait: { waits.append($0) }, step: {
            attempts += 1; return attempts == 3
        })
        precondition(success && attempts == 3 && waits == Array(repeating: 5_000_000_000, count: 3))
        attempts = 0; waits = []
        let exhausted = try await WakeReconnect.run(wait: { waits.append($0) }, step: {
            attempts += 1; return false
        })
        precondition(!exhausted && attempts == 8 && waits.reduce(0, +) == 40_000_000_000)
        attempts = 0
        do {
            _ = try await WakeReconnect.run(wait: { _ in throw CancellationError() }, step: { attempts += 1; return false })
            preconditionFailure("Cancellation ignored")
        } catch is CancellationError { precondition(attempts == 0) }
        print("PASS: delayed connection succeeds, retries bounded to40s, cancellation prevents attempts")
    }
}
