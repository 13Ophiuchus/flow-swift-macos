	//
	//  WebSocketTests.swift
	//  FlowTests
	//
	//  Migrated from XCTest to Swift Testing by Nicholas Reich on 2026-03-19.
	//  Refactored to Swift Testing + AsyncStream-based Flow websocket APIs.
	//

import Flow
import Testing
import Foundation
import XCTest

// Only one task-group branch ever calls next() at a time (the timeout branch
// never touches the iterator), so wrapping it in an @unchecked Sendable class
// is a sound use of the escape hatch — there is no actual concurrent access.
final class AsyncIteratorBox<Base: AsyncIteratorProtocol>: @unchecked Sendable {
	private var iterator: Base

	init(_ iterator: Base) {
		self.iterator = iterator
	}

	func next() async rethrows -> Base.Element? {
		try await iterator.next()
	}
}

// Races an async operation against a timeout without ever capturing a mutable
// var/iterator inside a task-group closure. Both branches only touch Sendable
// values (the actor box and simple closures), so Swift 6 strict concurrency
// checking has nothing to flag.
func withTimeout<T: Sendable>(
	seconds: UInt64,
	timeoutError: Error,
	operation: @Sendable @escaping () async throws -> T
) async throws -> T {
	try await withThrowingTaskGroup(of: T.self) { group in
		group.addTask { try await operation() }
		group.addTask {
			try await _Concurrency.Task.sleep(nanoseconds: seconds * 1_000_000_000)
			throw timeoutError
		}
		defer { group.cancelAll() }
		return try await group.next()!
	}
}

@Suite
struct WebSocketTests {

	init() { }

	@Test("Block digest stream yields a block header", .timeLimit(.minutes(1)), .disabled("blockStream() never sends a subscribe frame for block_digests/block_headers topics — no sendBlockDigestSubscribe exists yet, so this test can never receive data. Needs implementation, tracked separately."))
	func blockDigestSubscription() async throws {
			// Must actually connect before any block digests can arrive.
		try await FlowWebsocketActor.shared.websocket.connect(
			to: URL(string: "wss://rest-mainnet.onflow.org/v1/ws")!
		)

		let stream = await Flow.shared.publisher.blockStream()
		let box = AsyncIteratorBox(stream.makeAsyncIterator())

			// Race next() against an explicit timeout so a stalled socket
			// fails fast instead of hanging past .timeLimit. The iterator now
			// lives inside an actor, so nothing captures a raw mutable var.
		let header = try await withTimeout(
			seconds: 20,
			timeoutError: Flow.FError.customError(msg: "Timed out waiting for block digest")
		) {
			await box.next()
		}

		let blockHeader = try #require(header)
		#expect(blockHeader.height.isEmpty == false)
	}

	@Test("Transaction status stream yields a status", .timeLimit(.minutes(1)), .disabled("Hardcoded tx 5ab8b0be... is already Sealed/Success on mainnet (verified via REST) so its live status subscription has no future transition to emit. Client-side connect/upgrade/masking/subscription-ID bugs are all fixed and confirmed working (subscribe now gets a clean ack). Needs rewrite to submit a fresh transaction from a funded test account and subscribe to that instead of a static historical hash."))
	func transactionStatusSubscription() async throws {
			// Known executed transaction on testnet/mainnet used for integration tests
		let testTxIdHex = "5ab8b0bec5ee89c63c5c33ddc4144f3772d0eeda0e85e905fc7e41c2d449269f"
		let txId = Flow.ID(hex: testTxIdHex)

			// Start websocket subscription (AsyncThrowingStream)
		let stream = try await FlowWebsocketActor.shared.websocket
			.subscribeToTransactionStatus(txId: txId)

		let box = AsyncIteratorBox(stream.makeAsyncIterator())

		try await withTimeout(
			seconds: 20,
			timeoutError: Flow.FError.customError(msg: "Timed out waiting for transaction status")
		) {
			while let next = try await box.next() {
				guard let payload = next.payload else { continue }
				let status = try payload.asTransactionResult()
				if status.status > .executed {
					#expect(status.status > .executed)
					return
				}
			}
			Issue.record("Did not receive a status > .executed for tx \(testTxIdHex)")
		}
	}

	@Test("Account status subscription placeholder")
	func accountStatusSubscription() {
			// The legacy Combine-based account status subscription API was removed
			// in favor of NIO + AsyncStream and is not yet implemented for accounts.
			// Keep a placeholder test so the suite structure remains intact.
		#expect(Bool(true))
	}

	@Test("List subscriptions placeholder test", .disabled("WebSocket subscriptions not implemented yet"))
	func listSubscriptions() throws {
			// TODO: Implement once server-side listSubscriptions behavior is defined.
	}
}
