	//
	//  FlowAccess.swift
	//
	//  Created by Hao Fu on 28/10/2022.
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich on 2026-03-19.
	//

import Foundation

	/// Convenience façade on top of `accessAPI`.
	/// Prefer `Flow.shared.accessAPI` when you need a concrete `FlowAccessProtocol`.
public extension Flow {

		// MARK: - Connectivity

	func ping() async throws -> Bool {
		let api = await accessAPI
		return try await api.ping()
	}

		// MARK: - Blocks

	func getLatestBlockHeader(
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.BlockHeader {
		let api = await accessAPI
		return try await api.getLatestBlockHeader(blockStatus: blockStatus)
	}

	func getBlockHeaderById(id: Flow.ID) async throws -> Flow.BlockHeader {
		let api = await accessAPI
		return try await api.getBlockHeaderById(id: id)
	}

	func getBlockHeaderByHeight(height: UInt64) async throws -> Flow.BlockHeader {
		let api = await accessAPI
		return try await api.getBlockHeaderByHeight(height: height)
	}

	func getLatestBlock(
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.Block {
		let api = await accessAPI
		return try await api.getLatestBlock(blockStatus: blockStatus)
	}

	func getBlockById(id: Flow.ID) async throws -> Flow.Block {
		let api = await accessAPI
		return try await api.getBlockById(id: id)
	}

	func getBlockByHeight(height: UInt64) async throws -> Flow.Block {
		let api = await accessAPI
		return try await api.getBlockByHeight(height: height)
	}

		// MARK: - Collections

	func getCollectionById(id: Flow.ID) async throws -> Flow.Collection {
		let api = await accessAPI
		return try await api.getCollectionById(id: id)
	}

		// MARK: - Transactions

	func sendTransaction(transaction: Flow.Transaction) async throws -> Flow.ID {
		let api = await accessAPI
		return try await api.sendTransaction(transaction: transaction)
	}

	func getTransactionById(id: Flow.ID) async throws -> Flow.Transaction {
		let api = await accessAPI
		return try await api.getTransactionById(id: id)
	}

	func getTransactionResultById(id: Flow.ID) async throws -> Flow.TransactionResult {
		let api = await accessAPI
		return try await api.getTransactionResultById(id: id)
	}

		// MARK: - Accounts

	func getAccountAtLatestBlock(
		address: Flow.Address,
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.Account {
		let api = await accessAPI
		return try await api.getAccountAtLatestBlock(address: address, blockStatus: blockStatus)
	}

	func getAccountByBlockHeight(
		address: Flow.Address,
		height: UInt64
	) async throws -> Flow.Account {
		let api = await accessAPI
		return try await api.getAccountByBlockHeight(address: address, height: height)
	}

		// MARK: - Events

	func getEventsForHeightRange(
		type: String,
		range: ClosedRange<UInt64>
	) async throws -> [Flow.Event.Result] {
		let api = await accessAPI
		return try await api.getEventsForHeightRange(type: type, range: range)
	}

	func getEventsForBlockIds(
		type: String,
		ids: Set<Flow.ID>
	) async throws -> [Flow.Event.Result] {
		let api = await accessAPI
		return try await api.getEventsForBlockIds(type: type, ids: ids)
	}

		// MARK: - Scripts

	func executeScriptAtLatestBlock(
		script: Flow.Script,
		arguments: [Flow.Argument],
		blockStatus: Flow.BlockStatus = .final
	) async throws -> Flow.ScriptResponse {
		let api = await accessAPI
		return try await api.executeScriptAtLatestBlock(
			script: script,
			arguments: arguments,
			blockStatus: blockStatus
		)
	}

	func executeScriptAtBlockId(
		script: Flow.Script,
		blockId: Flow.ID,
		arguments: [Flow.Argument] = []
	) async throws -> Flow.ScriptResponse {
		let api = await accessAPI
		return try await api.executeScriptAtBlockId(
			script: script,
			blockId: blockId,
			arguments: arguments
		)
	}

	func executeScriptAtBlockHeight(
		script: Flow.Script,
		height: UInt64,
		arguments: [Flow.Argument] = []
	) async throws -> Flow.ScriptResponse {
		let api = await accessAPI
		return try await api.executeScriptAtBlockHeight(
			script: script,
			height: height,
			arguments: arguments
		)
	}

		// MARK: - Network parameters

	func getNetworkParameters() async throws -> Flow.ChainID {
		let api = await accessAPI
		return try await api.getNetworkParameters()
	}
}
