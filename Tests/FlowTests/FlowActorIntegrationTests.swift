	//
	//  FlowActorIntegrationTests.swift
	//  FlowTests
	//
	//  Integration tests: hit real Flow testnet.
	//  Guard every test with `.enabled(if:)` so CI doesn't block on network.
	//  Run locally by setting FLOW_INTEGRATION_TESTS=1 in your scheme env vars.
	//
	//  All tests are @FlowActor-isolated because they call into @FlowActor APIs.
	//

@testable import BigInt
@testable import Flow
import Foundation
import Testing

	// MARK: - Integration test condition

private var integrationEnabled: Bool {
	ProcessInfo.processInfo.environment["FLOW_INTEGRATION_TESTS"] == "1"
}

private let testnet = Flow.ChainID.testnet

	// MARK: - Network connectivity

@Suite(
	"Integration — FlowAccessActor live testnet",
	.enabled(if: integrationEnabled, "Set FLOW_INTEGRATION_TESTS=1 to run")
)
@FlowActor
struct FlowAccessActorIntegrationTests {

	init() async throws {
		await FlowActors.access.configure(chainID: testnet)
		await FlowActors.config.updateChainID(testnet)
	}

	@Test("ping returns true on testnet")
	func ping() async throws {
		let result = try await FlowActors.access.ping()
		#expect(result == true)
	}

	@Test("getLatestBlock returns a block with valid ID")
	func getLatestBlock() async throws {
			// Disambiguate overload: choose blockStatus-based version.
		let block = try await FlowActors.access.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(block.id.hex.isEmpty == false)
		#expect(block.height > 0)
	}

	@Test("getLatestBlockHeader returns valid header")
	func getLatestBlockHeader() async throws {
		let header = try await FlowActors.access.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(header.height > 0)
	}

	@Test("getNetworkParameters returns testnet chainID")
	func getNetworkParameters() async throws {
		let chainID = try await FlowActors.access.getNetworkParameters()
		#expect(chainID == testnet)
	}

	@Test("executeScriptAtLatestBlock returns decodable result")
	func executeScript() async throws {
		let script = Flow.Script(text: """
		access(all) fun main(): String {
			return "integration-ok"
		}
		""")
		let response = try await FlowActors.access.executeScriptAtLatestBlock(
			script: script,
			arguments: [],
			blockStatus: Flow.BlockStatus.final
		)
		let result: String = try response.decode()
		#expect(result == "integration-ok")
	}

	@Test("getAccountAtLatestBlock returns account for known testnet address")
	func getAccount() async throws {
			// Flow testnet fungible token contract — always exists.
		let knownAddress = "9a0766d93b6608b7"
		let account = try await FlowActors.access.getAccountAtLatestBlock(
			address: knownAddress,
			blockStatus: Flow.BlockStatus.final
		)
		#expect(account.address.hex.contains(knownAddress.lowercased()))
	}
}

// MARK: - Transaction build + send (integration, read-only path)

@Suite(
"Integration — buildTransaction on testnet",
.enabled(if: integrationEnabled, "Set FLOW_INTEGRATION_TESTS=1 to run")
)
@FlowActor
struct BuildTransactionIntegrationTests {

		// A testnet account you own with a funded key.
		// Override via environment variable so secrets stay out of source.
	private var proposerAddress: Flow.Address {
		let hex = ProcessInfo.processInfo.environment["FLOW_TEST_ADDRESS"]
		?? "9a0766d93b6608b7"
		return Flow.Address(hex: hex)
	}

	init() async {
		await FlowActors.config.updateChainID(testnet)
		await FlowActors.access.configure(chainID: testnet)
	}

	@Test("buildTransaction resolves live reference block and sequence number")
	func buildLiveTransaction() async throws {
		let tx = try await Flow.shared.buildTransaction(chainID: testnet) {
			cadence { "access(all) fun main() {}" }
			proposer { proposerAddress }
			payer { proposerAddress }
			authorizers { proposerAddress }
			gasLimit { 100 }
		}
		#expect(tx.referenceBlockId.hex.isEmpty == false)
		#expect(tx.proposalKey.sequenceNumber >= 0)
		#expect(tx.payer == proposerAddress)
	}

	@Test("executeScriptAtLatestBlock with arguments round-trips correctly")
	func scriptWithArguments() async throws {
			// Passing an address argument and returning it back is a useful smoke test.
		let script = Flow.Script(text: """
		access(all) fun main(addr: Address): Address {
			return addr
		}
		""")
		let arg = Flow.Cadence.FValue.address(proposerAddress).toArgument()
		let response = try await FlowActors.access.executeScriptAtLatestBlock(
			script: script,
			arguments: [arg],
			blockStatus: Flow.BlockStatus.final
		)
		let result: String = try response.decode()
		#expect(result.lowercased().contains(proposerAddress.hex.lowercased()))
	}
}

// MARK: - FlowConfigActor integration

@Suite(
"Integration — FlowConfigActor chain propagation",
.enabled(if: integrationEnabled, "Set FLOW_INTEGRATION_TESTS=1 to run")
)
struct FlowConfigActorIntegrationTests {

	@Test("chainID update is visible across actor boundary")
	func chainIDPropagation() async {
		await FlowActors.config.updateChainID(.testnet)
		let id = await FlowActors.config.chainID
		#expect(id == .testnet)
	}

	@Test("chainID defaults back when reset to mainnet")
	func resetToMainnet() async {
		await FlowActors.config.updateChainID(.testnet)
		await FlowActors.config.updateChainID(.mainnet)
		let id = await FlowActors.config.chainID
		#expect(id == .mainnet)
	}
}

// MARK: - WebSocket (smoke — no full round-trip without a live tx)

@Suite(
"Integration — FlowWebSocketCenter connect/disconnect",
.enabled(if: integrationEnabled, "Set FLOW_INTEGRATION_TESTS=1 to run")
)
struct FlowWebSocketIntegrationTests {

	@Test("connectIfNeeded does not throw on testnet")
	func connectToTestnet() async throws {
			// Reconfigure to testnet websocket endpoint.
		await FlowActors.config.updateChainID(.testnet)
			// connect should not throw; if it does the endpoint is wrong.
		try await FlowWebSocketCenter.shared.connectIfNeeded()
			// Clean up.
		await FlowWebSocketCenter.shared.disconnect()
	}

	@Test("subscribeToTransactionStatus returns a stream (not an error)")
	func subscribeReturnsStream() async throws {
		try await FlowWebSocketCenter.shared.connectIfNeeded()
			// Use a fake tx ID — we're only testing that the call path compiles
			// and returns without throwing before data arrives.
		let fakeID = Flow.ID(
			hex: "0xdeadbeef00000000000000000000000000000000000000000000000000000001"
		)
		let stream = try await FlowWebSocketCenter.shared.subscribeToTransactionStatus(id: fakeID)
		_ = stream
		await FlowWebSocketCenter.shared.disconnect()
	}
}
