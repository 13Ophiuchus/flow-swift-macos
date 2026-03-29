////
////  WebSocketTopic.swift
////  Flow
////
////  Created by Nicholas Reich on 3/26/26.
////
//
//
//public extension Flow {
//
//    enum WebSocketTopic: String, Codable, Sendable {
//        case transactionStatuses = "transactionStatuses"
//        // add others as needed
//    }
//
//    /// Generic Flow websocket envelope.
//    struct WebSocketEnvelope: Decodable, Sendable {
//        public let id: String?
//        public let topic: WebSocketTopic
//        public let payload: TransactionStatusBody?
//
//        // Map your actual JSON keys accordingly.
//        enum CodingKeys: String, CodingKey {
//            case id
//            case topic
//            case payload
//        }
//
//        // Convenience for handler
//        public var transactionStatusPayload: TransactionStatusBody? {
//            payload
//        }
//    }
//
//    /// Transaction status payload body from websocket.
//    struct TransactionStatusBody: Decodable, Sendable {
//        public let txId: String
//        public let status: Flow.Transaction.Status
//        public let errorMessage: String?
//        public let events: [Flow.Event.Result]?
//
//        public func asTransactionResult() throws -> Flow.TransactionResult {
//            // Construct a TransactionResult using your existing model.
//            Flow.TransactionResult(
//                id: Flow.ID(hex: txId),
//                status: status,
//                errorMessage: errorMessage,
//                events: events ?? []
//            )
//        }
//    }
//}
