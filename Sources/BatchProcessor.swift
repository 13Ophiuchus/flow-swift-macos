	//
	//  BatchProcessor.swift
	//  Flow
	//
	//  Created by Hao Fu on 4/4/2022.
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich on 2026-03-26.
	//

import Foundation

public typealias FlowData = [String: String]

	/// Concrete, Sendable output for script execution.
public struct ScriptExecutionResult: Sendable, Hashable {
	public let targetName: String
	public let rawValueDescription: String

	public init(
		targetName: String,
		rawValueDescription: String
	) {
		self.targetName = targetName
		self.rawValueDescription = rawValueDescription
	}
}

/// Actor responsible for running batched Flow operations.
public actor BatchProcessor {

	public init() {}

		// MARK: - Accounts

	public func processAccounts(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async throws -> [Flow.Address: FlowData] {
		try await process(
			addresses,
			maxConcurrent: maxConcurrent
		) { address in
			try await BatchProcessor.fetchAccountDataStatic(for: address)
		}
	}

	public func processAccountsSafely(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async -> [Flow.Address: Result<FlowData, Error>] {
		await processSafely(
			addresses,
			maxConcurrent: maxConcurrent
		) { address in
			try await BatchProcessor.fetchAccountDataStatic(for: address)
		}
	}

		// MARK: - Scripts

	public func executeScripts<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 8,
		operation: @Sendable @escaping (T) async throws -> ScriptExecutionResult
	) async throws -> [T: ScriptExecutionResult] {
		try await process(
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
		await processSafely(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

		// MARK: - Transactions

	public func sendTransactions<T: Hashable & Sendable>(
		_ targets: [T],
		maxConcurrent: Int = 4,
		operation: @Sendable @escaping (T) async throws -> Flow.ID
	) async throws -> [T: Flow.ID] {
		try await process(
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
		await processSafely(
			targets,
			maxConcurrent: maxConcurrent,
			operation: operation
		)
	}

		// MARK: - Generic helpers

	public func process<Key: Hashable & Sendable, Output: Sendable>(
		_ inputs: [Key],
		maxConcurrent: Int = 8,
		operation: @Sendable @escaping (Key) async throws -> Output
	) async throws -> [Key: Output] {
		var results: [Key: Output] = [:]

		try await withThrowingTaskGroup(of: (Key, Output).self) { group in
			var iterator = inputs.makeIterator()
			var inFlight = 0

			while inFlight < maxConcurrent, let next = iterator.next() {
				inFlight += 1
				let key = next
				group.addTask {
					let value = try await operation(key)
					return (key, value)
				}
			}

			while let (key, value) = try await group.next() {
				results[key] = value
				inFlight -= 1

				if let next = iterator.next() {
					inFlight += 1
					let key = next
					group.addTask {
						let value = try await operation(key)
						return (key, value)
					}
				}
			}
		}

		return results
	}

	public func processSafely<Key: Hashable & Sendable, Output: Sendable>(
		_ inputs: [Key],
		maxConcurrent: Int = 8,
		operation: @Sendable @escaping (Key) async throws -> Output
	) async -> [Key: Result<Output, Error>] {
		var results: [Key: Result<Output, Error>] = [:]

		await withTaskGroup(of: (Key, Result<Output, Error>).self) { group in
			var iterator = inputs.makeIterator()
			var inFlight = 0

			while inFlight < maxConcurrent, let next = iterator.next() {
				inFlight += 1
				let key = next
				group.addTask {
					do {
						let value = try await operation(key)
						return (key, .success(value))
					} catch {
						return (key, .failure(error))
					}
				}
			}

			while let (key, result) = await group.next() {
				results[key] = result
				inFlight -= 1

				if let next = iterator.next() {
					inFlight += 1
					let key = next
					group.addTask {
						do {
							let value = try await operation(key)
							return (key, .success(value))
						} catch {
							return (key, .failure(error))
						}
					}
				}
			}
		}

		return results
	}

		// MARK: - Internal helpers

	private static func fetchAccountDataStatic(for address: Flow.Address) async throws -> FlowData {
			// `currentClient` is a computed property — no parentheses.
		let api = await FlowActors.access.currentClient
		let account = try await api.getAccountAtLatestBlock(
			address: address.description
		)

		let balanceString = String(describing: account.balance)

		return [
			"address": account.address.hex,
			"balance": balanceString
		]
	}
}
