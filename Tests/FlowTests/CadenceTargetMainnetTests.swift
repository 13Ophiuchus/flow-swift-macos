	//
	//  CadenceTargetMainnetTests.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/25/26.
	//  Updated for Swift 6 concurrency & actor-based access on 2026-03-29.
	//

import Testing
@testable import Flow

@Suite
struct CadenceTargetMainnetTests {

	private let flow = Flow()

	init() async {
		await FlowAccessActor.shared.configure(chainID: Flow.ChainID.mainnet)
		await flow.configure(chainID: Flow.ChainID.mainnet)
	}

	@Test(.timeLimit(.minutes(1)))
	func query() async throws {
		let result: String? = try await flow.query(
			TestCadenceTarget.getCOAAddr(
				address: Flow.Address(hex: "0x84221fe0294044d7")
			),
			chainID: Flow.ChainID.mainnet
		)

		#expect(result != nil)
	}
}
