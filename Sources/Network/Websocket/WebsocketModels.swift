	//
	//  WebsocketModels.swift
	//  Flow
	//
	//  Created by Hao Fu on 29/4/2025.
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich on 2026-03-19.
	//

import Foundation

public extension Flow {

		// MARK: - Topics & actions

		/// High-level websocket topics used by the Flow access node.
	enum WebSocketTopic: String, Codable, Sendable {
		case blockDigests = "block_digests"
		case blockHeaders = "block_headers"
		case blocks = "blocks"
		case events = "events"
		case accountStatuses = "account_statuses"
		case transactionStatuses = "transaction_statuses"
		case sendAndGetTransactionStatuses = "send_and_get_transaction_statuses"
	}

		/// Websocket action verbs.
	enum WebSocketAction: String, Codable, Sendable {
		case subscribe = "subscribe"
		case unsubscribe = "unsubscribe"
		case listSubscriptions = "list_subscriptions"
	}

		// MARK: - Subscribe / topic responses

		/// Generic subscribe request for Flow websocket.
	struct WebSocketSubscribeRequest<Arguments: Encodable & Sendable>: Encodable, Sendable {
		public let id: String?
		public let action: WebSocketAction
		public let topic: WebSocketTopic?
		public let arguments: Arguments?

		enum CodingKeys: String, CodingKey {
			case id = "subscription_id"
			case action
			case topic
			case arguments
		}

		public init(
			id: String?,
			action: WebSocketAction,
			topic: WebSocketTopic?,
			arguments: Arguments?
		) {
			self.id = id
			self.action = action
			self.topic = topic
			self.arguments = arguments
		}
	}

		/// Response to a subscribe/unsubscribe/list request.
	struct WebSocketSubscribeResponse: Decodable, Sendable {
		public let subscriptionId: String
		public let action: WebSocketAction
		public let error: WebSocketSocketError?
	}

		/// Error payload from websocket.
	struct WebSocketSocketError: Codable, Sendable {
		public let code: Int
		public let message: String
	}

		/// Topic response carrying typed payload `T`.
	struct WebSocketTopicResponse<T: Decodable & Sendable>: Decodable, Sendable {
		public let subscriptionId: String
		public let topic: WebSocketTopic
		public let payload: T?
		public let error: WebSocketSocketError?
	}

		// MARK: - Transaction status envelope

		/// Generic Flow websocket envelope specifically for transaction status messages.
	struct WebSocketErrorBody: Decodable, Sendable {
		public let code: Int
		public let message: String
	}

	struct WebSocketEnvelope: Decodable, Sendable {
		public let id: String?
		public let topic: WebSocketTopic?
		public let payload: TransactionStatusBody?
		public let error: WebSocketErrorBody?

		enum CodingKeys: String, CodingKey {
			case id = "subscription_id"
			case topic
			case payload
			case error
		}

		public var transactionStatusPayload: TransactionStatusBody? {
			payload
		}
	}

		/// Transaction status payload body from websocket.
		/// Wire format nests all fields one level deeper, under
		/// `"transaction_result"`, with snake_case keys — e.g.
		/// `{ "transaction_result": { "status": "Executed", "block_id": "..." }, "message_index": 0 }`.
	struct TransactionStatusBody: Decodable, Sendable {
		public let txId: String?
		public let status: Flow.Transaction.Status
		public let errorMessage: String?
			// Websocket transaction_result.events is a flat array of individual
			// event objects, unlike the REST API's grouped Event.Result shape —
			// decode directly as [Flow.Event].
		public let events: [Flow.Event]?
		public let blockId: Flow.ID?
		public let computationUsed: Int?

		private enum OuterCodingKeys: String, CodingKey {
			case transactionResult = "transaction_result"
		}

		private enum InnerCodingKeys: String, CodingKey {
			case txId = "transaction_id"
			case status
			case errorMessage = "error_message"
			case events
			case blockId = "block_id"
			case computationUsed = "computation_used"
		}

		public init(from decoder: Decoder) throws {
			let outer = try decoder.container(keyedBy: OuterCodingKeys.self)
			let inner = try outer.nestedContainer(keyedBy: InnerCodingKeys.self, forKey: .transactionResult)

			self.txId = try inner.decodeIfPresent(String.self, forKey: .txId)
			self.status = try inner.decode(Flow.Transaction.Status.self, forKey: .status)
			self.errorMessage = try inner.decodeIfPresent(String.self, forKey: .errorMessage)
			self.events = try inner.decodeIfPresent([Flow.Event].self, forKey: .events)

			if let blockIdHex = try inner.decodeIfPresent(String.self, forKey: .blockId), !blockIdHex.isEmpty {
				self.blockId = Flow.ID(hex: blockIdHex)
			} else {
				self.blockId = nil
			}

			if let computationString = try inner.decodeIfPresent(String.self, forKey: .computationUsed) {
				self.computationUsed = Int(computationString)
			} else {
				self.computationUsed = try inner.decodeIfPresent(Int.self, forKey: .computationUsed)
			}
		}

		public func asTransactionResult() throws -> Flow.TransactionResult {
			let evs: [Flow.Event] = events ?? []

			let statusCode = status.rawValue   // or your own mapping

				// Early-stage statuses (e.g. Pending) may not yet have a block_id,
				// error_message, or computation_used populated by the access node.
				// Default gracefully instead of throwing so callers can still see
				// the current status while waiting for later messages.
			return Flow.TransactionResult(
				status: status,
				errorMessage: errorMessage ?? "",
				events: evs,
				statusCode: statusCode,
				blockId: blockId ?? Flow.ID(data: Data(repeating: 0, count: 32)),
				computationUsed: (computationUsed ?? 0).description
			)
		}

	}
}
