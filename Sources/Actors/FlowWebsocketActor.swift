	//
	//  FlowWebsocketActor.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/22/26.
	//  Modernized to delegate to FlowWebSocketCenter (NIO) while using
	//  Swift Concurrency (AsyncStream) instead of Combine.
	//

import Foundation

	// MARK: - Global Websocket Actor

@globalActor
public actor FlowWebsocketActor {
	public static let shared = FlowWebsocketActor()

	public let websocket: Flow.Websocket

	public init() {
		self.websocket = Flow.Websocket()
	}
}

// MARK: - Websocket actor façade

public extension Flow {

		/// Websocket façade that delegates to FlowWebSocketCenter + NIO
		/// and exposes AsyncStream-based APIs.
	actor Websocket {

			// MARK: State

		private var isConnected = false

		public init() {}

			// MARK: - Connection

		public func connect(to url: URL) {
			_Concurrency.Task { [weak self] in
				guard let self else { return }
				do {
					try await FlowWebSocketCenter.shared.connectIfNeeded()
					await self.setConnected(true)
				} catch {
					await self.sendError(error)
				}
			}
		}

		public func disconnect() {
			_Concurrency.Task { [weak self] in
				guard let self else { return }
				await FlowWebSocketCenter.shared.disconnect()
				await self.setConnected(false)
			}
		}

			// MARK: - Transaction status subscription

			/// Returns an AsyncThrowingStream of raw topic responses for a given
			/// transaction ID. The stream is backed by FlowWebSocketCenter's shared
			/// envelope bus, filtered to this tx ID only.
		public func subscribeToTransactionStatus(
			txId: Flow.ID
		) async throws -> AsyncThrowingStream<TopicResponse<Flow.TransactionStatusBody>, Error> {
				// subscribeToTransactionStatus now sends the subscribe frame AND
				// returns a properly typed AsyncThrowingStream — no intermediate
				// `()` assignment needed.
			let stream = try await FlowWebSocketCenter.shared.subscribeToTransactionStatus(id: txId)

				// Wrap so we can also publish high-level events as each response arrives.
			return AsyncThrowingStream { continuation in
				_Concurrency.Task {
					do {
						for try await response in stream {
							guard let payload = response.payload else { continue }

							let txResult = try payload.asTransactionResult()

							await Flow.shared.publisher.publishTransactionStatus(
								id: txId,
								status: txResult
							)

								// Pass response directly — no rewrap needed, types already match.
							continuation.yield(response)
						}
						continuation.finish()
					} catch {
						await self.sendError(error)
						continuation.finish(throwing: error)
					}
				}
			}
		}

			/// Convenience helper to build streams for multiple transaction IDs.
		@FlowWebsocketActor
		public static func subscribeToManyTransactionStatuses(
			txIds: [Flow.ID]
		) async throws -> [Flow.ID: AsyncThrowingStream<TopicResponse<Flow.TransactionStatusBody>, Error>] {
			var result: [Flow.ID: AsyncThrowingStream<TopicResponse<Flow.TransactionStatusBody>, Error>] = [:]

			for id in txIds {
				let stream = try await FlowWebsocketActor.shared.websocket
					.subscribeToTransactionStatus(txId: id)
				result[id] = stream
			}

			return result
		}

			// MARK: - Helpers

		private func setConnected(_ status: Bool) async {
			isConnected = status
			await Flow.publishConnectionStatus(isConnected: status)
		}

		private func sendError(_ error: Error) async {
			await Flow.publishError(error)
		}
	}
}

public extension Flow {
	@FlowActor
	static func publishConnectionStatus(isConnected: Bool) async {
		await Flow.shared.publisher.publishConnectionStatus(isConnected: isConnected)
	}

	@FlowActor
	static func publishError(_ error: Error) async {
		await Flow.shared.publisher.publishError(error)
	}
}

// MARK: - Models

public extension Flow {
	struct Topic: RawRepresentable, Sendable {
		public let rawValue: String

		public init(rawValue: String) {
			self.rawValue = rawValue
		}

		public static func transactionStatus(txId: Flow.ID) -> Topic {
			Topic(rawValue: "transactionStatus:\(txId.hex)")
		}
	}

	struct TopicResponse<T: Decodable & Sendable>: Decodable, Sendable {
		public let subscriptionId: String
		public let payload: T?
	}

	struct SubscribeResponse: Decodable {
		public struct ErrorBody: Decodable, Sendable {
			public let message: String
			public let code: Int?
		}

		public let id: String
		public let error: ErrorBody?
	}

	enum WebSocketError: Error {
		case serverError(SubscribeResponse.ErrorBody)
	}
}
