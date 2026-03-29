	//
	//  MockFlowAccessAPI.swift
	//  FlowTests
	//
	//  Shared mock for all unit tests. Conforms to FlowAccessProtocol so it can
	//  be injected via FlowAccessActor.configure(chainID:accessAPI:).
	//  All responses are configurable stubs; unexpected calls throw MockError.notStubbed.
	//

import BigInt
import Foundation
@testable import Flow

	// MARK: - Error

enum MockError: Error {
	case notStubbed(String)
	case intentional(String)
}

	// MARK: - MockFlowAccessAPI

	/// Drop-in replacement for FlowHTTPAPI in tests.
	/// Set the `stub_*` properties before each test; reset between tests.
final class MockFlowAccessAPI: FlowAccessProtocol, @unchecked Sendable {

		// MARK: - Stubs (set these in test setUp)

	var stub_ping: Bool = true
	var stub_latestBlockHeader: Flow.BlockHeader?
	var stub_blockHeaderById: Flow.BlockHeader?
	var stub_blockHeaderByHeight: Flow.BlockHeader?
	var stub_latestBlock: Flow.Block?
	var stub_blockById: Flow.Block?
	var stub_blockByHeight: Flow.Block?
	var stub_collection: Flow.Collection?
	var stub_sendTransactionID: Flow.ID?
	var stub_transaction: Flow.Transaction?
	var stub_transactionResult: Flow.TransactionResult?
	var stub_account: Flow.Account?
	var stub_scriptResponse: Flow.ScriptResponse?
	var stub_events: [Flow.Event.Result] = []
	var stub_chainID: Flow.ChainID = .testnet

		// Set to non-nil to make a call throw instead of returning its stub.
	var stub_error: Error?

		// Call counts — assert on these to verify interactions.
	private(set) var callCount_ping = 0
	private(set) var callCount_sendTransaction = 0
	private(set) var callCount_executeScriptAtLatestBlock = 0
	private(set) var callCount_getAccountAtLatestBlock = 0
	private(set) var callCount_getLatestBlock = 0

		// MARK: - Reset

	func reset() {
		stub_ping = true
		stub_latestBlockHeader = nil
		stub_blockHeaderById = nil
		stub_blockHeaderByHeight = nil
		stub_latestBlock = nil
		stub_blockById = nil
		stub_blockByHeight = nil
		stub_collection = nil
		stub_sendTransactionID = nil
		stub_transaction = nil
		stub_transactionResult = nil
		stub_account = nil
		stub_scriptResponse = nil
		stub_events = []
		stub_chainID = .testnet
		stub_error = nil
		callCount_ping = 0
		callCount_sendTransaction = 0
		callCount_executeScriptAtLatestBlock = 0
		callCount_getAccountAtLatestBlock = 0
		callCount_getLatestBlock = 0
	}

		// MARK: - Helpers

	private func maybeThrow() throws {
		if let error = stub_error { throw error }
	}

	private func require<T>(_ value: T?, name: String) throws -> T {
		guard let value else { throw MockError.notStubbed(name) }
		return value
	}

		// MARK: - FlowAccessProtocol

	func ping() async throws -> Bool {
		callCount_ping += 1
		try maybeThrow()
		return stub_ping
	}

	func getLatestBlockHeader(blockStatus: Flow.BlockStatus) async throws -> Flow.BlockHeader {
		try maybeThrow()
		return try require(stub_latestBlockHeader, name: "latestBlockHeader")
	}

	func getBlockHeaderById(id: Flow.ID) async throws -> Flow.BlockHeader {
		try maybeThrow()
		return try require(stub_blockHeaderById, name: "blockHeaderById")
	}

	func getBlockHeaderByHeight(height: UInt64) async throws -> Flow.BlockHeader {
		try maybeThrow()
		return try require(stub_blockHeaderByHeight, name: "blockHeaderByHeight")
	}

	func getLatestBlock(blockStatus: Flow.BlockStatus) async throws -> Flow.Block {
		callCount_getLatestBlock += 1
		try maybeThrow()
		return try require(stub_latestBlock, name: "latestBlock")
	}

	func getLatestBlock(sealed: Bool) async throws -> Flow.Block {
		callCount_getLatestBlock += 1
		try maybeThrow()
		return try require(stub_latestBlock, name: "latestBlock(sealed:)")
	}

	func getBlockById(id: Flow.ID) async throws -> Flow.Block {
		try maybeThrow()
		return try require(stub_blockById, name: "blockById")
	}

	func getBlockByHeight(height: UInt64) async throws -> Flow.Block {
		try maybeThrow()
		return try require(stub_blockByHeight, name: "blockByHeight")
	}

	func getCollectionById(id: Flow.ID) async throws -> Flow.Collection {
		try maybeThrow()
		return try require(stub_collection, name: "collection")
	}

	func sendTransaction(transaction: Flow.Transaction) async throws -> Flow.ID {
		callCount_sendTransaction += 1
		try maybeThrow()
		return try require(stub_sendTransactionID, name: "sendTransactionID")
	}

	func getTransactionById(id: Flow.ID) async throws -> Flow.Transaction {
		try maybeThrow()
		return try require(stub_transaction, name: "transaction")
	}

	func getTransactionResultById(id: Flow.ID) async throws -> Flow.TransactionResult {
		try maybeThrow()
		return try require(stub_transactionResult, name: "transactionResult")
	}

	func getAccountAtLatestBlock(
		address: Flow.Address,
		blockStatus: Flow.BlockStatus
	) async throws -> Flow.Account {
		callCount_getAccountAtLatestBlock += 1
		try maybeThrow()
		return try require(stub_account, name: "account(address:)")
	}

	func getAccountAtLatestBlock(
		address: String,
		blockStatus: Flow.BlockStatus
	) async throws -> Flow.Account {
		callCount_getAccountAtLatestBlock += 1
		try maybeThrow()
		return try require(stub_account, name: "account(string:)")
	}

	func getAccountByBlockHeight(
		address: Flow.Address,
		height: UInt64
	) async throws -> Flow.Account {
		try maybeThrow()
		return try require(stub_account, name: "accountByBlockHeight")
	}

	func executeScriptAtLatestBlock(
		script: Flow.Script,
		arguments: [Flow.Argument],
		blockStatus: Flow.BlockStatus
	) async throws -> Flow.ScriptResponse {
		callCount_executeScriptAtLatestBlock += 1
		try maybeThrow()
		return try require(stub_scriptResponse, name: "scriptResponse")
	}

	func executeScriptAtBlockId(
		script: Flow.Script,
		blockId: Flow.ID,
		arguments: [Flow.Argument]
	) async throws -> Flow.ScriptResponse {
		try maybeThrow()
		return try require(stub_scriptResponse, name: "scriptResponse(blockId:)")
	}

	func executeScriptAtBlockHeight(
		script: Flow.Script,
		height: UInt64,
		arguments: [Flow.Argument]
	) async throws -> Flow.ScriptResponse {
		try maybeThrow()
		return try require(stub_scriptResponse, name: "scriptResponse(height:)")
	}

	func getEventsForHeightRange(
		type: String,
		range: ClosedRange<UInt64>
	) async throws -> [Flow.Event.Result] {
		try maybeThrow()
		return stub_events
	}

	func getEventsForBlockIds(
		type: String,
		ids: Set<Flow.ID>
	) async throws -> [Flow.Event.Result] {
		try maybeThrow()
		return stub_events
	}

	func getNetworkParameters() async throws -> Flow.ChainID {
		try maybeThrow()
		return stub_chainID
	}
}

	// MARK: - Fixture factory

extension MockFlowAccessAPI {

		/// A minimal valid Flow.Block suitable for use as a reference block.
	static func makeBlock(
		id: String = "0xdeadbeef00000000000000000000000000000000000000000000000000000000"
	) -> Flow.Block {
		Flow.Block(
			id: Flow.ID(hex: id),
			parentId: Flow.ID(hex: "0x0000000000000000000000000000000000000000000000000000000000000000"),
			height: 100,
			timestamp: Date(),
			collectionGuarantees: [],
			blockSeals: [],
			signatures: []
		)
	}

		/// A minimal valid account with one key at index 0.
		///
		/// Adjust to your real `Flow.Account` & `Flow.AccountKey` initializers.
	static func makeAccount(
		address: String = "0x01cf0e2f2f715450",
		sequenceNumber: Int64 = 42
	) -> Flow.Account {
		let accountKey = Flow.AccountKey(
			index: 0,
			publicKey: Flow.PublicKey(hex: "abc123"),
			signAlgo: Flow.SignatureAlgorithm.ECDSA_P256,
			hashAlgo: Flow.HashAlgorithm.SHA2_256,
			weight: 1000,
			sequenceNumber: sequenceNumber,
			revoked: false
		)

		return Flow.Account(
			address: Flow.Address(hex: address),
			balance: 10,
			keys: [accountKey],
			contracts: [:]
		)
	}

		/// A canned ScriptResponse that decodes to the given value when `.decode()` is called.
		///
		/// This assumes your `Flow.ScriptResponse` internally stores Cadence JSON directly.
	static func makeScriptResponse<T: Encodable>(
		value: T,
		cadenceType: String
	) throws -> Flow.ScriptResponse {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys

		let encodedValue = try encoder.encode(value)
		let valueJSON = String(data: encodedValue, encoding: .utf8) ?? "null"

		let wrapped = """
  {"type":"\(cadenceType)","value":\(valueJSON)}
  """

		let data = wrapped.data(using: .utf8) ?? Data()
		return Flow.ScriptResponse(data: data)
	}
}

