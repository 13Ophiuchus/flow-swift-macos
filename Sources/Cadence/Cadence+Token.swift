	//
	//  Cadence+Token.swift
	//  Flow
	//
	//  Created by Hao Fu on 4/4/2025.
	//  Edited for Swift 6 concurrency & actors by Nicholas Reich on 2026-03-27.
	//

import SwiftUI

	// MARK: - Cadence Loader Category

extension CadenceLoader.Category {
	public enum Token: String, CaseIterable, CadenceLoaderProtocol {
		case getTokenBalanceStorage = "get_token_balance_storage"

		public var filename: String { rawValue }
	}
}

// MARK: - Flow convenience API (non-isolated; does not capture self)

public extension Flow {
	/// Get all token balances for an account using the Cadence script
	/// `get_token_balance_storage`.
	///
	/// This function itself is non-isolated; it delegates to actor-isolated
	/// helpers (FlowActor / FlowAccessActor) so there is no "sending self".
	func getTokenBalance(
	address: Flow.Address
	) async throws -> [String: Decimal] {
		// Load script without touching shared mutable state.
		let scriptSource = try await CadenceLoader.load(
		CadenceLoader.Category.Token.getTokenBalanceStorage
		)

			// `currentClient` is a computed property — no parentheses.
		let accessAPI = await FlowAccessActor.shared.currentClient

		let response = try await accessAPI.executeScriptAtLatestBlock(
			script: Flow.Script(text: scriptSource),
			arguments: [Flow.Cadence.FValue.address(address).toArgument()],
			blockStatus: Flow.BlockStatus.final
		)

			// Decoding is pure and nonisolated (see FlowArgument+Decode.swift).
		let decoded: [String: Decimal] = try response.decode()
		return decoded
	}
}

// MARK: - Actor-safe Token Manager for UI

@MainActor
final class TokenManager: ObservableObject {
	@Published var balances: [String: Decimal] = [:]
	@Published var isLoading = false
	@Published var error: Error?

	private let flow: Flow

	init(flow: Flow) {
		self.flow = flow
	}

		/// Fire-and-forget load suitable for SwiftUI call sites.
		/// Example:
		///     Button("Refresh") { tokenManager.loadBalances(for: address) }
	func loadBalances(for address: Flow.Address) {
		isLoading = true
		error = nil

		_Concurrency.Task { [flow] in
			do {
					// Call non-isolated Flow API; it will internally hop to actors as needed.
				let balances = try await flow.getTokenBalance(address: address)

					// Back on MainActor (Task inherits MainActor from caller).
				self.balances = balances
				self.isLoading = false
				self.error = nil
			} catch {
				self.error = error
				self.isLoading = false
			}
		}
	}
}
