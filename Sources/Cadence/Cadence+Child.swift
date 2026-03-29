	//
	//  Cadence+Child.swift
	//  Flow
	//
	//  Created by Hao Fu on 1/4/2025.
	//
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich on 2026-03-19.

import SwiftUI

extension CadenceLoader.Category {
	public enum Child: String, CaseIterable, CadenceLoaderProtocol {
		case getChildAddress = "get_child_addresses"
		case getChildAccountMeta = "get_child_account_meta"

		public var filename: String { rawValue }
	}
}

// Metadata structure for child accounts
extension CadenceLoader.Category.Child {
	public struct Metadata: Codable {
		public let name: String?
		public let description: String?
		public let thumbnail: Thumbnail?

		public struct Thumbnail: Codable {
			public let urlString: String?

			public var url: URL? {
				guard let urlString else { return nil }
				return URL(string: urlString)
			}

			enum CodingKeys: String, CodingKey {
				case urlString = "url"
			}
		}
	}
}

// Swift 6 async extensions; keep them on FlowActor to avoid cross‑actor captures.

public extension Flow {
	/// Fetch child account addresses
	func getChildAddress(address: Flow.Address) async throws -> [Flow.Address] {
		let script = try await CadenceLoader.load(
		CadenceLoader.Category.Child.getChildAddress
		)
		return try await executeScriptAtLatestBlock(
		script: .init(text: script),
		arguments: [Flow.Cadence.FValue.address(address).toArgument()]
			).decode()
	}

		/// Fetch child account metadata
	func getChildMetadata(
		address: Flow.Address
	) async throws -> [String: CadenceLoader.Category.Child.Metadata] {
		let script = try await CadenceLoader.load(
			CadenceLoader.Category.Child.getChildAccountMeta
		)
		return try await executeScriptAtLatestBlock(
			script: .init(text: script),
			arguments: [Flow.Cadence.FValue.address(address).toArgument()]
		).decode()
	}
}
