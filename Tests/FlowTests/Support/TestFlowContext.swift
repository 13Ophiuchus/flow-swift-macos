//
//  TestFlowContext.swift
//  FlowTests
//
//  Scoped helper to configure FlowAccessActor.shared for a single test,
//  then restore prior global state afterward. Prevents cross-test pollution
//  of the shared actor singleton (chainID + accessAPI client).
//

import Foundation
@testable import Flow

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
