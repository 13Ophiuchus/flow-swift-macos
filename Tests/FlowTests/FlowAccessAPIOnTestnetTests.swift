	//
	//  FlowAccessAPIOnTestnetTests.swift
	//  FlowTests
	//

@testable import Flow
import Foundation
import Testing

@Suite
struct FlowAccessAPIOnTestnetTests {

		// MARK: - Helpers

	private func makeTestnetAPI() async -> FlowAccessActor {
		let api = FlowAccessActor(initialChainID: Flow.ChainID.testnet)
		await api.configure(chainID: Flow.ChainID.testnet)
		return api
	}

	private func makeScript(_ text: String) -> Flow.Script {
		Flow.Script(text: text)
	}

	private func makeArguments(_ values: [Flow.Cadence.FValue]) -> [Flow.Argument] {
		values.map { $0.toArgument() }
	}

		// MARK: - Basic connectivity

	@Test("Ping testnet")
	func pingTestnet() async throws {
		let api = await makeTestnetAPI()
		let result = try await api.ping()
		#expect(result == true)
	}

	@Test("Get testnet network parameters")
	func getNetworkParameters() async throws {
		let api = await makeTestnetAPI()
		let chainID = try await api.getNetworkParameters()
		#expect(chainID == Flow.ChainID.testnet)
	}

		// MARK: - Block headers

	@Test("Get latest testnet block header")
	func getLatestBlockHeader() async throws {
		let api = await makeTestnetAPI()
		let header = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(header.height >= 0)
	}

	@Test("Get latest testnet block")
	func getLatestBlock() async throws {
		let api = await makeTestnetAPI()
		let block = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		#expect(block.height >= 0)
	}

	@Test("Get latest sealed testnet block")
	func getLatestSealedBlock() async throws {
		let api = await makeTestnetAPI()
		let block = try await api.getLatestBlock(sealed: true)
		#expect(block.height >= 0)
	}

	@Test("Get testnet block by height")
	func getBlockByHeight() async throws {
		let api = await makeTestnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		let block = try await api.getBlockByHeight(height: latest.height)
		#expect(block.height == latest.height)
	}

	@Test("Get testnet block header by height")
	func getBlockHeaderByHeight() async throws {
		let api = await makeTestnetAPI()
		let latest = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		let header = try await api.getBlockHeaderByHeight(height: latest.height)
		#expect(header.height == latest.height)
	}

	@Test("Get testnet block by id")
	func getBlockById() async throws {
		let api = await makeTestnetAPI()
		let latest = try await api.getLatestBlock(
			blockStatus: Flow.BlockStatus.final
		)
		let block = try await api.getBlockById(id: latest.id)
		#expect(block.id == latest.id)
	}

	@Test("Get testnet block header by id")
	func getBlockHeaderById() async throws {
		let api = await makeTestnetAPI()
		let latest = try await api.getLatestBlockHeader(
			blockStatus: Flow.BlockStatus.final
		)
		let header = try await api.getBlockHeaderById(id: latest.id)
		#expect(header.id == latest.id)
	}

		// MARK: - Accounts

	@Test("Get testnet service account at latest block by address")
	func getAccountAtLatestBlockByAddress() async throws {
		let api = await makeTestnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7") // replace with real testnet addr if needed

		let account = try await api.getAccountAtLatestBlock(
			address: address,
			blockStatus: Flow.BlockStatus.final
		)

		#expect(account.address == address)
	}

	@Test("Get testnet service account at latest block by string")
	func getAccountAtLatestBlockByString() async throws {
		let api = await makeTestnetAPI()
		let addressString = "0xf8d6e0586b0a20c7" // replace with real testnet addr if needed

		let account = try await api.getAccountAtLatestBlock(
			address: addressString,
			blockStatus: Flow.BlockStatus.final
		)

		#expect(account.address.hex.lowercased() == addressString.lowercased())
	}

	@Test("Get testnet account by block height")
	func getAccountByBlockHeight() async throws {
		let api = await makeTestnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7") // replace with real testnet addr if needed
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

	@Test("Execute no-arg script at latest testnet block")
	func executeScriptAtLatestBlockNoArgs() async throws {
		let api = await makeTestnetAPI()

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

	@Test("Execute address-arg script at latest testnet block")
	func executeScriptAtLatestBlockWithAddressArg() async throws {
		let api = await makeTestnetAPI()
		let address = Flow.Address(hex: "0xf8d6e0586b0a20c7") // testnet addr

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

	@Test("Execute testnet script at block id")
	func executeScriptAtBlockId() async throws {
		let api = await makeTestnetAPI()
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

	@Test("Execute testnet script at block height")
	func executeScriptAtBlockHeight() async throws {
		let api = await makeTestnetAPI()
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

	@Test("Execute testnet script with multiple cadence values")
	func executeScriptWithMultipleArguments() async throws {
		let api = await makeTestnetAPI()

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

	@Test("Get testnet events for height range")
	func getEventsForHeightRange() async throws {
		let api = await makeTestnetAPI()
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

	@Test("Get testnet events for block ids")
	func getEventsForBlockIds() async throws {
		let api = await makeTestnetAPI()
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
