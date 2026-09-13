//
//  MockFlowAccessAPI.swift
//  FlowTests
//
//  Shared mock for all unit tests. Conforms to FlowAccessProtocol so it can
//  be injected via FlowAccessActor.configure(chainID:accessAPI:).
//  All responses are configurable stubs; unexpected calls throw MockError.notStubbed.
//

import BigInt
@testable import Flow
import Foundation

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

    func getLatestBlockHeader(blockStatus _: Flow.BlockStatus) async throws -> Flow.BlockHeader {
        try maybeThrow()
        return try require(stub_latestBlockHeader, name: "latestBlockHeader")
    }

    func getBlockHeaderById(id _: Flow.ID) async throws -> Flow.BlockHeader {
        try maybeThrow()
        return try require(stub_blockHeaderById, name: "blockHeaderById")
    }

    func getBlockHeaderByHeight(height _: UInt64) async throws -> Flow.BlockHeader {
        try maybeThrow()
        return try require(stub_blockHeaderByHeight, name: "blockHeaderByHeight")
    }

    func getLatestBlock(blockStatus _: Flow.BlockStatus) async throws -> Flow.Block {
        callCount_getLatestBlock += 1
        try maybeThrow()
        return try require(stub_latestBlock, name: "latestBlock")
    }

    func getLatestBlock(sealed _: Bool) async throws -> Flow.Block {
        callCount_getLatestBlock += 1
        try maybeThrow()
        return try require(stub_latestBlock, name: "latestBlock(sealed:)")
    }

    func getBlockById(id _: Flow.ID) async throws -> Flow.Block {
        try maybeThrow()
        return try require(stub_blockById, name: "blockById")
    }

    func getBlockByHeight(height _: UInt64) async throws -> Flow.Block {
        try maybeThrow()
        return try require(stub_blockByHeight, name: "blockByHeight")
    }

    func getCollectionById(id _: Flow.ID) async throws -> Flow.Collection {
        try maybeThrow()
        return try require(stub_collection, name: "collection")
    }

    func sendTransaction(transaction _: Flow.Transaction) async throws -> Flow.ID {
        callCount_sendTransaction += 1
        try maybeThrow()
        return try require(stub_sendTransactionID, name: "sendTransactionID")
    }

    func getTransactionById(id _: Flow.ID) async throws -> Flow.Transaction {
        try maybeThrow()
        return try require(stub_transaction, name: "transaction")
    }

    func getTransactionResultById(id _: Flow.ID) async throws -> Flow.TransactionResult {
        try maybeThrow()
        return try require(stub_transactionResult, name: "transactionResult")
    }

    func getAccountAtLatestBlock(
        address _: Flow.Address,
        blockStatus _: Flow.BlockStatus
    ) async throws -> Flow.Account {
        callCount_getAccountAtLatestBlock += 1
        try maybeThrow()
        return try require(stub_account, name: "account(address:)")
    }

    func getAccountAtLatestBlock(
        address _: String,
        blockStatus _: Flow.BlockStatus
    ) async throws -> Flow.Account {
        callCount_getAccountAtLatestBlock += 1
        try maybeThrow()
        return try require(stub_account, name: "account(string:)")
    }

    func getAccountByBlockHeight(
        address _: Flow.Address,
        height _: UInt64
    ) async throws -> Flow.Account {
        try maybeThrow()
        return try require(stub_account, name: "accountByBlockHeight")
    }

    func executeScriptAtLatestBlock(
        script _: Flow.Script,
        arguments _: [Flow.Argument],
        blockStatus _: Flow.BlockStatus
    ) async throws -> Flow.ScriptResponse {
        callCount_executeScriptAtLatestBlock += 1
        try maybeThrow()
        return try require(stub_scriptResponse, name: "scriptResponse")
    }

    func executeScriptAtBlockId(
        script _: Flow.Script,
        blockId _: Flow.ID,
        arguments _: [Flow.Argument]
    ) async throws -> Flow.ScriptResponse {
        try maybeThrow()
        return try require(stub_scriptResponse, name: "scriptResponse(blockId:)")
    }

    func executeScriptAtBlockHeight(
        script _: Flow.Script,
        height _: UInt64,
        arguments _: [Flow.Argument]
    ) async throws -> Flow.ScriptResponse {
        try maybeThrow()
        return try require(stub_scriptResponse, name: "scriptResponse(height:)")
    }

    func getEventsForHeightRange(
        type _: String,
        range _: ClosedRange<UInt64>
    ) async throws -> [Flow.Event.Result] {
        try maybeThrow()
        return stub_events
    }

    func getEventsForBlockIds(
        type _: String,
        ids _: Set<Flow.ID>
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
        address: String = "0x7e60df042a9c0868",
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
