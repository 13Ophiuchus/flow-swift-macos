//
//  CadenceTargetMainnetTests.swift
//  Flow
//
//  Created by Nicholas Reich on 3/25/26.
//  Updated for Swift 6 concurrency & actor-based access on 2026-03-29.
//

@testable import Flow
import Testing

@Suite(.serialized)
struct CadenceTargetMainnetTests {
    // TestFlowActor configures the global FlowActors.access singleton for mainnet.
    // Flow.shared.query() routes through FlowActors.access.currentClient internally.
    private let flow = TestFlowActor.mainnet()

    init() async {
        await flow.access.configure(chainID: .mainnet)
        await FlowActors.config.updateChainID(.mainnet)
    }

    @Test(.timeLimit(.minutes(1)))
    func query() async throws {
        let result: String? = try await Flow.shared.query(
            TestCadenceTarget.getCOAAddr(
                address: Flow.Address(hex: "0x84221fe0294044d7")
            ),
            chainID: .mainnet
        )

        #expect(result != nil)
    }
}
