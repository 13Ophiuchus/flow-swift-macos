	//
	//  FlowWebSocketCenter.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/22/26.
	//

import Foundation
import NIOCore
import NIOPosix
import NIOHTTP1
import NIOWebSocket
@preconcurrency import NIOSSL

	/// Central coordinator for WebSocket connections and subscriptions.
public actor FlowWebSocketCenter {

	public static let shared = FlowWebSocketCenter()

	private let nioClient: FlowNIOWebSocketClient

		// MARK: - Shared envelope bus
		//
		// All decoded inbound envelopes from the NIO pipeline are funnelled into
		// this single AsyncStream via `envelopeContinuation`. Each call to
		// `subscribeToTransactionStatus` creates a child AsyncThrowingStream that
		// filters by subscription ID — no fan-out library needed.
	private let envelopeContinuation: AsyncStream<Flow.WebSocketEnvelope>.Continuation
	public  let envelopes: AsyncStream<Flow.WebSocketEnvelope>

	private static let defaultAddressesJSONPath: String =
	"/Users/nicreich/flow-swift-macos/Sources/Cadence/addresses.json"

		/// Designated initialiser. Pass a custom `nioClient` in tests.
	public init(nioClient: FlowNIOWebSocketClient? = nil) {
			// Build the shared envelope stream first so the continuation
			// is stored in a `let` before we capture it — this satisfies
			// Swift 6's rule that a `var` cannot be referenced in a
			// concurrently-executing (@Sendable) closure (error at old line 45).
		var cont: AsyncStream<Flow.WebSocketEnvelope>.Continuation!
		self.envelopes = AsyncStream { cont = $0 }
		self.envelopeContinuation = cont  // now a `let`; safe to capture below

			// Capture the stored `let` property, not the local `var`.
			// AsyncStream.Continuation is Sendable, so this closure is safe.
		let deliver: @Sendable (Flow.WebSocketEnvelope) -> Void = { [cont] in
			cont!.yield($0)
		}

		if let nioClient {
			self.nioClient = nioClient
		} else {
			let client = try? FlowNIOWebSocketClient(
				addressesJSONPath: Self.defaultAddressesJSONPath,
				onEnvelope: deliver
			)
			self.nioClient = client ?? FlowNIOWebSocketClient(
				addresses: [],
				group: MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount),
				configActor: .shared,
				onEnvelope: deliver
			)
		}
	}

		// MARK: - Public API

		/// Ensure the WebSocket connection is active.
	public func connectIfNeeded() async throws {
		try await nioClient.connectIfNeeded()
	}

	public func disconnect() async {
		await nioClient.disconnect()
		envelopeContinuation.finish()
	}

		/// Send a subscribe frame and return an `AsyncThrowingStream` of decoded
		/// `TransactionStatusBody` payloads for the given transaction ID.
		///
		/// `Flow.WebSocketEnvelope.id` carries the subscription ID (not `subscriptionId`).
	public func subscribeToTransactionStatus(
		id: Flow.ID
	) async throws -> AsyncThrowingStream<Flow.TopicResponse<Flow.TransactionStatusBody>, Error> {
		await nioClient.sendTransactionStatusSubscribe(id: id)

			// AsyncStream is Sendable — safe to capture into the Task below.
		let envelopes = self.envelopes
		let subscriptionId = "tx:\(id.hex)"

		return AsyncThrowingStream { continuation in
			_Concurrency.Task {
				for await envelope in envelopes {
						// `WebSocketEnvelope.id` is the subscription ID field —
						// there is no `subscriptionId` property (old line 91 error).
					guard
						envelope.topic == .transactionStatuses,
						envelope.id == subscriptionId,
						let payload = envelope.transactionStatusPayload
					else { continue }

					continuation.yield(
						Flow.TopicResponse(
							subscriptionId: envelope.id ?? subscriptionId,
							payload: payload
						)
					)
				}
				continuation.finish()
			}
		}
	}
}

