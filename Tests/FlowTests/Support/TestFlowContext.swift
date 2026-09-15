//
//  TestFlowContext.swift
//  FlowTests
//
//  Integration-test helper ONLY.
//
//  USE IN: FlowAccessAPIOnTestnetTests, FlowAccessAPIOnMainnetTests,
//          FlowActorIntegrationTests, WebSocketLiveTransactionTests —
//          i.e. tests that must reconfigure the *real* shared singleton
//          against a live network endpoint.
//
//  DO NOT USE IN UNIT TESTS. Unit test suites must create their own
//  FlowAccessActor(initialChainID:) and pass it via the `access:` parameter
//  of buildTransaction/sendTransaction. Mutating FlowActors.access from a
//  unit suite causes races when suites run concurrently.
//

@testable import Flow
import Foundation

@FlowActor
func withTestFlowContext<T>(
    chainID: Flow.ChainID,
    accessAPI: (any FlowAccessProtocol)? = nil,
    _ body: () async throws -> T
) async throws -> T {
    let originalChainID = await FlowActors.config.chainID
    let originalClient = await FlowActors.access.currentClient

    await FlowActors.access.configure(chainID: chainID, accessAPI: accessAPI)

    do {
        let result = try await body()
        await FlowActors.access.configure(chainID: originalChainID, accessAPI: originalClient)
        return result
    } catch {
        await FlowActors.access.configure(chainID: originalChainID, accessAPI: originalClient)
        throw error
    }
}
