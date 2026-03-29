import Foundation

public enum FlowActors {
	static let access    = FlowAccessActor.shared
	static let websocket = FlowWebSocketCenter.shared
	static let config    = FlowConfigActor.shared
	static let crypto    = FlowCryptoActor.shared
}

public final class Flow: @unchecked Sendable {
	@FlowActor
	public static let shared = Flow()

	public let defaultUserAgent = userAgent

		// Not exposed as mutable public API; internal use only.
	internal var addressRegisterStorage = ContractAddressRegister()

	public var encoder: JSONEncoder {
		let encoder = JSONEncoder()
		encoder.outputFormatting = .sortedKeys
		return encoder
	}

	public var decoder: JSONDecoder { JSONDecoder() }

	public init() {}

		// MARK: - Config

	public var chainID: ChainID {
		get async { await FlowActors.config.chainID }
	}

	public func configure(chainID: ChainID) async {
		await FlowActors.access.configure(chainID: chainID, accessAPI: nil)
	}

	public func configure(chainID: ChainID, accessAPI: FlowAccessProtocol) async {
		await FlowActors.access.configure(chainID: chainID, accessAPI: accessAPI)
	}

	public func createHTTPAccessAPI(chainID: ChainID) -> FlowAccessProtocol {
		FlowHTTPAPI(chainID: chainID)
	}

	public var accessAPI: FlowAccessProtocol {
		get async { await FlowActors.access.currentClient }
	}

	public var websocketCenter: FlowWebSocketCenter {
		FlowActors.websocket
	}
}

	// High-level helpers; already safe because heavy work is in actors.
@FlowActor
public extension Flow {

	func once(
		_ transactionId: Flow.ID,
		status: Flow.Transaction.Status,
		timeout: TimeInterval = 60
	) async throws -> Flow.TransactionResult {
		try await transactionId.once(status: status, timeout: timeout)
	}

	func onceFinalized(_ transactionId: Flow.ID) async throws -> Flow.TransactionResult {
		try await once(transactionId, status: .finalized)
	}

	func onceExecuted(_ transactionId: Flow.ID) async throws -> Flow.TransactionResult {
		try await once(transactionId, status: .executed)
	}

	func onceSealed(_ transactionId: Flow.ID) async throws -> Flow.TransactionResult {
		try await once(transactionId, status: .sealed)
	}

	func isAddressVaildate(
		address: Flow.Address,
		network: Flow.ChainID = .mainnet
	) async -> Bool {
		do {
			let accessAPI = createHTTPAccessAPI(chainID: network)
			_ = try await accessAPI.getAccountAtLatestBlock(
				address: address,
				blockStatus: .final
			)
			return true
		} catch {
			return false
		}
	}
}
