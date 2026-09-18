//
//  CadenceTargetMainnetTests.swift
//  Flow
//
//  Created by Nicholas Reich on 3/25/26.
//  Updated for Swift 6 concurrency & actor-based access on 2026-03-29.
//
//  NOTE: This is a live network integration test (mainnet). It requires
//  an active internet connection and will be skipped in offline/CI environments
//  that cannot reach access.mainnet.nodes.onflow.org.
//

@testable import Flow
import Testing

@Suite(.serialized)
struct CadenceTargetMainnetTests {
    // Async factory — configure is fully awaited before the suite body runs.
    // The local actor is then injected directly into query() so no global
    // singleton mutation is needed.
    private let access: FlowAccessActor

    init() async {
        let actor = FlowAccessActor()
        // syncConfig: false — suite-local actor; must not mutate FlowActors.config
        // which is shared state raced by concurrent test suites.
        await actor.configure(chainID: .mainnet, syncConfig: false)
        self.access = actor
    }

    @Test(.timeLimit(.minutes(1)))
    func query() async throws {
        let result: String? = try await Flow.shared.query(
            TestCadenceTarget.getCOAAddr(
                address: Flow.Address(hex: "0x84221fe0294044d7")
            ),
            chainID: .mainnet,
            access: access
        )

        #expect(result != nil)
    }
}
