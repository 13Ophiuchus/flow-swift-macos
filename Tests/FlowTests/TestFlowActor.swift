import Flow

/// Per-suite isolated FlowAccessActor — NOT the global singleton.
/// Supports both regular and @FlowActor-isolated @Suite structs.
///
/// For non-isolated suites (default):
///   private let flow = TestFlowActor.testnet()     // sync factory, fire-and-forget Task
///
/// For @FlowActor-isolated suites (e.g. FlowAccessActorIntegrationTests):
///   private var flow: TestFlowActor!
///   init() async throws { flow = try await TestFlowActor.testnetAsync() }
struct TestFlowActor {
    let access: FlowAccessActor

    // MARK: - Sync factories (fire-and-forget configure — for non-isolated suites)

    static func testnet() -> TestFlowActor {
        let a = FlowAccessActor()
        Task { await a.configure(chainID: .testnet) }
        return TestFlowActor(access: a)
    }

    static func mainnet() -> TestFlowActor {
        let a = FlowAccessActor()
        Task { await a.configure(chainID: .mainnet) }
        return TestFlowActor(access: a)
    }

    // MARK: - Async factories (awaited configure — for @FlowActor-isolated suites)

    static func testnetAsync() async -> TestFlowActor {
        let a = FlowAccessActor()
        await a.configure(chainID: .testnet)
        return TestFlowActor(access: a)
    }

    static func mainnetAsync() async -> TestFlowActor {
        let a = FlowAccessActor()
        await a.configure(chainID: .mainnet)
        return TestFlowActor(access: a)
    }
}
