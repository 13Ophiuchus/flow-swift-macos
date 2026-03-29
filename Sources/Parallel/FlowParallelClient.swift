	//
	//  FlowParallelClient.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 2026-03-26.
	//

import Foundation

	// MARK: - Injectable executor types

public typealias FlowScriptInspector = @Sendable (
	_ target: any CadenceTargetType,
	_ chainID: Flow.ChainID
) async throws -> ScriptExecutionResult

public typealias FlowTransactionSender = @Sendable (
	_ target: any CadenceTargetType,
	_ signers: [FlowSigner],
	_ chainID: Flow.ChainID
) async throws -> Flow.ID

	// MARK: - FlowParallelClient

	/// High-level façade for parallel account, script, and transaction work.
public actor FlowParallelClient {

	private let batchProcessor: BatchProcessor
	private let scriptInspector: FlowScriptInspector
	private let transactionSender: FlowTransactionSender

		// MARK: - Init

	public init(
		batchProcessor: BatchProcessor = BatchProcessor(),
		scriptInspector: FlowScriptInspector? = nil,
		transactionSender: FlowTransactionSender? = nil
	) {
		self.batchProcessor = batchProcessor

		self.scriptInspector = scriptInspector ?? { target, chainID in
			let flow = Flow()
			let decoded = try await flow.query(
				target,
				chainID: chainID
			) as ParallelInspectableDecodable

			return ScriptExecutionResult(
				targetName: String(describing: target),
				rawValueDescription: decoded.value
			)
		}

		self.transactionSender = transactionSender ?? { target, signers, chainID in
			let flow = Flow()
			return try await flow.sendTransaction(
				target,
				signers: signers,
				chainID: chainID
			)
		}
	}

		// MARK: - Accounts

	public func loadAccounts(
		fromAddressJSON path: String,
		maxConcurrent: Int = 8
	) async throws -> [Flow.Address: FlowData] {
		let addresses = try FlowAddressLoader.loadAddressList(fromPath: path)
		return try await batchProcessor.processAccounts(
			addresses,
			maxConcurrent: maxConcurrent
		)
	}

	public func loadAccounts(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async throws -> [Flow.Address: FlowData] {
		try await batchProcessor.processAccounts(
			addresses,
			maxConcurrent: maxConcurrent
		)
	}

	public func loadAccountsSafely(
		fromAddressJSON path: String,
		maxConcurrent: Int = 8
	) async -> [Flow.Address: Result<FlowData, Error>] {
		do {
			let addresses = try FlowAddressLoader.loadAddressList(fromPath: path)
			return await batchProcessor.processAccountsSafely(
				addresses,
				maxConcurrent: maxConcurrent
			)
		} catch {
			return [:]
		}
	}

	public func loadAccountsSafely(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async -> [Flow.Address: Result<FlowData, Error>] {
		await batchProcessor.processAccountsSafely(
			addresses,
			maxConcurrent: maxConcurrent
		)
	}

		// MARK: - Generic scripts (closure-based)

	public func executeScripts<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 8,
		operation: @Sendable @escaping (T) async throws -> ScriptExecutionResult
	) async throws -> [T: ScriptExecutionResult] {
		try await batchProcessor.executeScripts(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

	public func executeScriptsSafely<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 8,
		operation: @Sendable @escaping (T) async throws -> ScriptExecutionResult
	) async -> [T: Result<ScriptExecutionResult, Error>] {
		await batchProcessor.executeScriptsSafely(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

		// MARK: - Inspection-friendly query results (injectable)

	public func executeScripts<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async throws -> [T: ScriptExecutionResult] {
		let inspector = scriptInspector
		return try await batchProcessor.executeScripts(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> ScriptExecutionResult in
			try await inspector(target, chainID)
		}
	}

	public func executeScriptsSafely<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async -> [T: Result<ScriptExecutionResult, Error>] {
		let inspector = scriptInspector
		return await batchProcessor.executeScriptsSafely(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> ScriptExecutionResult in
			try await inspector(target, chainID)
		}
	}

		// MARK: - Fully typed decoded query results

	public func executeScripts<T: CadenceTargetType & Hashable & Sendable, Output: Decodable & Sendable>(
		_ targets: [T],
		as: Output.Type,
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async throws -> [T: Output] {
		try await batchProcessor.process(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> Output in
			let flow = Flow()
			return try await flow.query(target, chainID: chainID)
		}
	}

	public func executeScriptsSafely<T: CadenceTargetType & Hashable & Sendable, Output: Decodable & Sendable>(
		_ targets: [T],
		as: Output.Type,
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async -> [T: Result<Output, Error>] {
		await batchProcessor.processSafely(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> Output in
			let flow = Flow()
			return try await flow.query(target, chainID: chainID)
		}
	}

		// MARK: - Query-only helpers

	public func executeQueryScripts<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async throws -> [T: ScriptExecutionResult] {
		let filtered = targets.filter { $0.type == .query }
		return try await executeScripts(
			filtered,
			chainID: chainID,
			maxConcurrent: maxConcurrent
		)
	}

	public func executeQueryScriptsSafely<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async -> [T: Result<ScriptExecutionResult, Error>] {
		let filtered = targets.filter { $0.type == .query }
		return await executeScriptsSafely(
			filtered,
			chainID: chainID,
			maxConcurrent: maxConcurrent
		)
	}

	public func executeQueryScripts<T: CadenceTargetType & Hashable & Sendable, Output: Decodable & Sendable>(
		_ targets: [T],
		as: Output.Type,
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async throws -> [T: Output] {
		let filtered = targets.filter { $0.type == .query }
		return try await executeScripts(
			filtered,
			as: Output.self,
			chainID: chainID,
			maxConcurrent: maxConcurrent
		)
	}

	public func executeQueryScriptsSafely<T: CadenceTargetType & Hashable & Sendable, Output: Decodable & Sendable>(
		_ targets: [T],
		as: Output.Type,
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 8
	) async -> [T: Result<Output, Error>] {
		let filtered = targets.filter { $0.type == .query }
		return await executeScriptsSafely(
			filtered,
			as: Output.self,
			chainID: chainID,
			maxConcurrent: maxConcurrent
		)
	}

		// MARK: - Generic transactions (closure-based)

	public func sendTransactions<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 4,
		operation: @Sendable @escaping (T) async throws -> Flow.ID
	) async throws -> [T: Flow.ID] {
		try await batchProcessor.sendTransactions(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

	public func sendTransactionsSafely<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 4,
		operation: @Sendable @escaping (T) async throws -> Flow.ID
	) async -> [T: Result<Flow.ID, Error>] {
		await batchProcessor.sendTransactionsSafely(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

		// MARK: - Typed transactions (injectable)

	public func sendTransactions<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		signers: [FlowSigner],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 4
	) async throws -> [T: Flow.ID] {
		let sender = transactionSender
		return try await batchProcessor.sendTransactions(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> Flow.ID in
			try await sender(target, signers, chainID)
		}
	}

	public func sendTransactionsSafely<T: CadenceTargetType & Hashable & Sendable>(
		_ targets: [T],
		signers: [FlowSigner],
		chainID: Flow.ChainID = .mainnet,
		maxConcurrent: Int = 4
	) async -> [T: Result<Flow.ID, Error>] {
		let sender = transactionSender
		return await batchProcessor.sendTransactionsSafely(
			targets,
			maxConcurrent: maxConcurrent
		) { (target: T) async throws -> Flow.ID in
			try await sender(target, signers, chainID)
		}
	}
}

	// MARK: - Private helpers

private struct ParallelInspectableDecodable: Decodable, Sendable {
	let value: String

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()

		if let string = try? container.decode(String.self) {
			value = string
		} else if let int = try? container.decode(Int.self) {
			value = String(int)
		} else if let double = try? container.decode(Double.self) {
			value = String(double)
		} else if let bool = try? container.decode(Bool.self) {
			value = String(bool)
		} else {
			value = "<non-scalar decoded value>"
		}
	}
}

