	//
	//  FlowAccessActor.swift
	//  Flow
	//
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich.
	//

import Foundation

public actor FlowAccessActor {
	public static let shared = FlowAccessActor()

	private var client: any FlowAccessProtocol

	public init(initialChainID: Flow.ChainID = .mainnet) {
		self.client = FlowHTTPAPI(chainID: initialChainID)
	}

	public func configure(
		chainID: Flow.ChainID,
		accessAPI: (any FlowAccessProtocol)? = nil
	) async {
		if let accessAPI {
			self.client = accessAPI
		} else {
			self.client = FlowHTTPAPI(chainID: chainID)
		}
	}

	public var currentClient: any FlowAccessProtocol {
		client
	}

	public func ping() async throws -> Bool {
		try await client.ping()
	}

	public func getLatestBlockHeader(
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.BlockHeader {
		try await client.getLatestBlockHeader(blockStatus: blockStatus)
	}

	public func getBlockHeaderById(id: Flow.ID) async throws -> Flow.BlockHeader {
		try await client.getBlockHeaderById(id: id)
	}

	public func getBlockHeaderByHeight(height: UInt64) async throws -> Flow.BlockHeader {
		try await client.getBlockHeaderByHeight(height: height)
	}

	public func getLatestBlock(
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.Block {
		try await client.getLatestBlock(blockStatus: blockStatus)
	}

	public func getLatestBlock(
		sealed: Bool = true
	) async throws -> Flow.Block {
		try await client.getLatestBlock(sealed: sealed)
	}

	public func getBlockById(id: Flow.ID) async throws -> Flow.Block {
		try await client.getBlockById(id: id)
	}

	public func getBlockByHeight(height: UInt64) async throws -> Flow.Block {
		try await client.getBlockByHeight(height: height)
	}

	public func getCollectionById(id: Flow.ID) async throws -> Flow.Collection {
		try await client.getCollectionById(id: id)
	}

	public func sendTransaction(
		transaction: Flow.Transaction
	) async throws -> Flow.ID {
		try await client.sendTransaction(transaction: transaction)
	}

	public func getTransactionById(id: Flow.ID) async throws -> Flow.Transaction {
		try await client.getTransactionById(id: id)
	}

	public func getTransactionResultById(id: Flow.ID) async throws -> Flow.TransactionResult {
		try await client.getTransactionResultById(id: id)
	}

	public func getAccountAtLatestBlock(
		address: Flow.Address,
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.Account {
		try await client.getAccountAtLatestBlock(address: address, blockStatus: blockStatus)
	}

	public func getAccountAtLatestBlock(
		address: String,
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.Account {
		try await client.getAccountAtLatestBlock(address: address, blockStatus: blockStatus)
	}

	public func getAccountByBlockHeight(
		address: Flow.Address,
		height: UInt64
	) async throws -> Flow.Account {
		try await client.getAccountByBlockHeight(address: address, height: height)
	}

	public func executeScriptAtLatestBlock(
		script: Flow.Script,
		arguments: [Flow.Argument],
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.ScriptResponse {
		try await client.executeScriptAtLatestBlock(
			script: script,
			arguments: arguments,
			blockStatus: blockStatus
		)
	}

	public func executeScriptAtBlockId(
		script: Flow.Script,
		blockId: Flow.ID,
		arguments: [Flow.Argument]
	) async throws -> Flow.ScriptResponse {
		try await client.executeScriptAtBlockId(
			script: script,
			blockId: blockId,
			arguments: arguments
		)
	}

	public func executeScriptAtBlockHeight(
		script: Flow.Script,
		height: UInt64,
		arguments: [Flow.Argument]
	) async throws -> Flow.ScriptResponse {
		try await client.executeScriptAtBlockHeight(
			script: script,
			height: height,
			arguments: arguments
		)
	}

	public func getEventsForHeightRange(
		type: String,
		range: ClosedRange<UInt64>
	) async throws -> [Flow.Event.Result] {
		try await client.getEventsForHeightRange(type: type, range: range)
	}

	public func getEventsForBlockIds(
		type: String,
		ids: Set<Flow.ID>
	) async throws -> [Flow.Event.Result] {
		try await client.getEventsForBlockIds(type: type, ids: ids)
	}

	public func getNetworkParameters() async throws -> Flow.ChainID {
		try await client.getNetworkParameters()
	}
}
