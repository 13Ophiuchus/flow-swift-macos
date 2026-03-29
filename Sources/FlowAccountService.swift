//
//  FlowAccountService.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


	/// Thin service wrapper around BatchProcessor.
public struct FlowAccountService {

	private let batchProcessor: BatchProcessor

	public init(batchProcessor: BatchProcessor = BatchProcessor()) {
		self.batchProcessor = batchProcessor
	}

	public func loadAccounts(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async throws -> [Flow.Address: FlowData] {
		try await batchProcessor.processAccounts(addresses, maxConcurrent: maxConcurrent)
	}

	public func loadAccountsSafely(
		_ addresses: [Flow.Address],
		maxConcurrent: Int = 8
	) async -> [Flow.Address: Result<FlowData, Error>] {
		await batchProcessor.processAccountsSafely(addresses, maxConcurrent: maxConcurrent)
	}
}
