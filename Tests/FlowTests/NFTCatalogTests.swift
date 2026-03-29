	//
	//  NFTCatalogTests.swift
	//  FlowTests
	//
	//  Created by Hao Fu on 20/8/2022.
	//  Migrated to Swift Testing by Nicholas Reich on 2026-03-19.
	//

@testable import Flow
import Foundation
import Testing

@Suite
struct NFTCatalogTests {

	private func makeTestFlow(chainID: Flow.ChainID) async -> Flow {
		var flow = Flow()
		await flow.configure(chainID: chainID)
		return flow
	}

	@Test("Can initialize testnet flow")
	func testnetFlowInit() async throws {
		let flow = await makeTestFlow(chainID: Flow.ChainID.testnet)
		await #expect(flow.chainID == Flow.ChainID.testnet)
	}

	@Test("Can initialize mainnet flow")
	func mainnetFlowInit() async throws {
		let flow = await makeTestFlow(chainID: Flow.ChainID.mainnet)
		await #expect(flow.chainID == Flow.ChainID.mainnet)
	}

	@Test("Can create NFT catalog address")
	func createCatalogAddress() async throws {
		let address = Flow.Address(hex: "0x04")
		#expect(address.bytes.count == Flow.Address.byteLength)
		#expect(address.hex.hasPrefix("0x"))
	}

	@Test("Address normalization is stable")
	func normalizedAddress() async throws {
		let address = Flow.Address(hex: "0x04")
		let rebuilt = Flow.Address(hex: address.hex)

		#expect(rebuilt == address)
		#expect(rebuilt.description == address.description)
	}
}
