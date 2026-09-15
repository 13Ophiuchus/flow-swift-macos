//
//  CadenceTargetTestnetTests.swift
//  Flow
//
//  Created by Nicholas Reich on 3/25/26.
//

@testable import Flow
import Testing

@Suite(.serialized)
@FlowActor
struct CadenceTargetTestnetTests {
    private let flow = TestFlowActor.testnet()
    init() async {
        await flow.access.configure(chainID: .testnet)
    }

    @Test(.timeLimit(.minutes(1)))
    func transactionTargetBuilds() async throws {
        _ = TestCadenceTarget.logTx(test: "Hi!")
        #expect(Bool(true))
    }
}
