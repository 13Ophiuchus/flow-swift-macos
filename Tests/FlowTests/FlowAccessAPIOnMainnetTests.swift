	//
	//  FlowAccessAPIOnMainnetTests.swift
	//  FlowTests
	//
	//  Updated for FlowAccessActor-based API access.
	//

@testable import Flow
import Foundation
import Testing

@Suite
struct FlowAccessAPIOnMainnetTests {

		// MARK: - Helpers

	private func makeMainnetAPI() async -> FlowAccessActor {
		let api = FlowAccessActor(initialChainID: Flow.ChainID.mainnet)
		await api.configure(chainID: Flow.ChainID.mainnet)
		return api
	}

	private func makeScript(_ text: String) -> Flow.Script {
		Flow.Script(text: text)
	}

	private func makeArguments(_ values: [Flow.Cadence.FValue]) -> [Flow.Argument] {
		values.map { $0.toArgument() }
	}

		// MARK: - Basic connectivity

	@Test("Ping mainnet")
	func pingMainnet() async throws {
		let api = await makeMainnetAPI()
		let result = try await api.ping()
		#expect(result == true)
	}

	@Test("Get network parameters")
	func getNetworkParameters() async throws {
		let api = await makeMainnetAPI()
		let chainID = try await api.getNetworkParameters()
		#expect(chainID == Flow.ChainID.mainnet)
	}

		// MARK: - Block headers

	@Test("Get latest block header")
	func getLatestBlockHeader() async throws {
		let api = await makeMainnetAPI()
		let header = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(header.height >= 0)
	}

	@Test("Get latest block")
	func getLatestBlock() async throws {
		let api = await makeMainnetAPI()
		let block = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(block.height >= 0)
	}

	@Test("Get latest sealed block")
	func getLatestSealedBlock() async throws {
		let api = await makeMainnetAPI()
		let block = try await api.getLatestBlock(sealed: true)
		#expect(block.height >= 0)
	}

	@Test("Get block by height")
	func getBlockByHeight() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		let block = try await api.getBlockByHeight(height: latest.height)
		#expect(block.height == latest.height)
	}

	@Test("Get block header by height")
	func getBlockHeaderByHeight() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		let header = try await api.getBlockHeaderByHeight(height: latest.height)
		#expect(header.height == latest.height)
	}

	@Test("Get block by id")
	func getBlockById() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		let block = try await api.getBlockById(id: latest.id)
		#expect(block.id == latest.id)
	}

	@Test("Get block header by id")
	func getBlockHeaderById() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		let header = try await api.getBlockHeaderById(id: latest.id)
		#expect(header.id == latest.id)
	}

		// MARK: - Accounts

	@Test("Get service account at latest block by address")
	func getAccountAtLatestBlockByAddress() async throws {
		let api = await makeMainnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7")

		let account = try await api.getAccountAtLatestBlock(
			address: address,
			blockStatus: Flow.BlockStatus.final
		)

		#expect(account.address == address)
	}

	@Test("Get service account at latest block by string")
	func getAccountAtLatestBlockByString() async throws {
		let api = await makeMainnetAPI()
		let addressString = "0xf8d6e0586b0a20c7"

		let account = try await api.getAccountAtLatestBlock(
			address: addressString,
			blockStatus: Flow.BlockStatus.final
		)

		#expect(account.address.hex.lowercased() == addressString.lowercased())
	}

	@Test("Get account by block height")
	func getAccountByBlockHeight() async throws {
		let api = await makeMainnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7")
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)

		let account = try await api.getAccountByBlockHeight(
			address: address,
			height: latest.height
		)

		#expect(account.address == address)
	}

		// MARK: - Scripts

	@Test("Execute no-arg script at latest block")
	func executeScriptAtLatestBlockNoArgs() async throws {
		let api = await makeMainnetAPI()

		let script = makeScript("""
		access(all) fun main(): Int {
			return 42
		}
		""")

		let response = try await api.executeScriptAtLatestBlock(
			script: script,
			arguments: [],
			blockStatus: Flow.BlockStatus.final
		)

		let value: Int = try response.decode()
		#expect(value == 42)
	}

	@Test("Execute address-arg script at latest block")
	func executeScriptAtLatestBlockWithAddressArg() async throws {
		let api = await makeMainnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7")

		let script = makeScript("""
		access(all) fun main(addr: Address): Address {
			return addr
		}
		""")

		let response = try await api.executeScriptAtLatestBlock(
			script: script,
			arguments: makeArguments([
				.address(address)
			]),
			blockStatus: Flow.BlockStatus.final
		)

		let value: Flow.Address = try response.decode()
		#expect(value == address)
	}

	@Test("Execute script at block id")
	func executeScriptAtBlockId() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)

		let script = makeScript("""
		access(all) fun main(): String {
			return "ok"
		}
		""")

		let response = try await api.executeScriptAtBlockId(
			script: script,
			blockId: latest.id,
			arguments: []
		)

		let value: String = try response.decode()
		#expect(value == "ok")
	}

	@Test("Execute script at block height")
	func executeScriptAtBlockHeight() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)

		let script = makeScript("""
		access(all) fun main(): Int {
			return 7
		}
		""")

		let response = try await api.executeScriptAtBlockHeight(
			script: script,
			height: latest.height,
			arguments: []
		)

		let value: Int = try response.decode()
		#expect(value == 7)
	}

	@Test("Execute script with multiple cadence values")
	func executeScriptWithMultipleArguments() async throws {
		let api = await makeMainnetAPI()

		let script = makeScript("""
		access(all) fun main(a: Int, b: String): String {
			return b
		}
		""")

		let cadenceValues: [Flow.Cadence.FValue] = [
			.int(10),
			.string("hello")
		]

		let response = try await api.executeScriptAtLatestBlock(
			script: script,
			arguments: makeArguments(cadenceValues),
			blockStatus: Flow.BlockStatus.final
		)

		let value: String = try response.decode()
		#expect(value == "hello")
	}

		// MARK: - Events

	@Test("Get events for height range")
	func getEventsForHeightRange() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)

		let lower = max(0, Int(latest.height) - 2)
		let range = UInt64(lower)...latest.height

		let results = try await api.getEventsForHeightRange(
			type: "A.1654653399040a61.FlowToken.TokensDeposited",
			range: range
		)

		#expect(results.count >= 0)
	}

	@Test("Get events for block ids")
	func getEventsForBlockIds() async throws {
		let api = await makeMainnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)

		let results = try await api.getEventsForBlockIds(
			type: "A.1654653399040a61.FlowToken.TokensDeposited",
			ids: [latest.id]
		)

		#expect(results.count >= 0)
	}
}
