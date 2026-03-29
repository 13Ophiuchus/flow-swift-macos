	//
	//  FlowId.swift
	//
	//  Based on Outblock/flow-swift ID model,
	//  adapted for Swift 6 concurrency by Nicholas Reich, 2026-03-19.
	//

import Foundation

public extension Flow {

		/// The ID in Flow chain, which can represent a transaction id, block id,
		/// collection id, etc.
	struct ID: FlowEntity, Equatable, Hashable, Sendable {
			/// Raw ID bytes (big-endian).
		public var  data: Data

			/// Create an ID from raw bytes.
		public init(data: Data) {
			self.data = data
		}

			/// Create an ID from a hex string (with or without "0x" prefix).
		public init(hex: String) {
			self.data = hex.hexValue.data
		}

			/// Create an ID from an array of bytes.
		public init(bytes: [UInt8]) {
			self.data = bytes.data
		}

			/// Create an ID from a slice of bytes.
		public init(bytes: ArraySlice<UInt8>) {
			self.data = Data(bytes)
		}
	}
}

	// MARK: - Codable (hex string representation)

extension Flow.ID: Codable {
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let hexString = try container.decode(String.self)
		self.init(hex: hexString)
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(self.hex)
	}
}

	// MARK: - CustomStringConvertible

extension Flow.ID: CustomStringConvertible {
	public var description: String { hex }
}

	// MARK: - Concurrency helpers (wait for transaction status)


public extension Flow.ID {

		/// Wait until the transaction reaches at least the desired status, or times out.
		/// Currently implemented via HTTP polling; WebSocket streaming can be reintroduced
		/// by extending FlowWebSocketCenter later.
	func once(
		status desiredStatus: Flow.Transaction.Status,
		timeout: TimeInterval = 60
	) async throws -> Flow.TransactionResult {

		let api = await FlowActors.access.currentClient
		let deadline = Date().addingTimeInterval(timeout)

		while Date() < deadline {
			let result = try await api.getTransactionResultById(id: self)

			if result.status.rawValue >= desiredStatus.rawValue {
				return result
			}

			try await _Concurrency.Task.sleep(nanoseconds: 500_000_000) // 0.5s
		}

		throw Flow.FError.customError(
			msg: "Timeout waiting for transaction status \(desiredStatus) for \(self.hex)"
		)
	}
}
