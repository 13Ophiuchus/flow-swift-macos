import Foundation

public enum CadenceType: String {
    case query
    case transaction
}

public protocol CadenceTargetType {
    /// Base64-encoded Cadence script
    var cadenceBase64: String { get }

    /// Script type (query or transaction)
    var type: CadenceType { get }

    /// Return type for decoding
    var returnType: Decodable.Type { get }

    /// Script arguments
    var arguments: [Flow.Argument] { get }
}

// MARK: - Generic execution extensions on Flow

public extension Flow {
    /// Query with generic return type.
    ///
    /// - Parameter access: The `FlowAccessActor` to use for the RPC call.
    ///   Defaults to the global `FlowActors.access` singleton for production
    ///   callers. Pass a suite-local actor in tests to avoid global state mutation.
    func query<T: Decodable>(
        _ target: CadenceTargetType,
        chainID _: Flow.ChainID = .mainnet,
        access: FlowAccessActor = FlowActors.access
    ) async throws -> T {
        guard let data = Data(base64Encoded: target.cadenceBase64) else {
            throw NSError(domain: "Invalid Cadence Base64 String", code: 9_900_001)
        }

        let script = Flow.Script(data: data)
        let api = await access.currentClient

        let response = try await api.executeScriptAtLatestBlock(
            script: script,
            arguments: target.arguments.map { $0.value }
        )

        return try response.decode()
    }

    /// Build, sign, and send a transaction from a `CadenceTargetType`.
    ///
    /// - Parameter access: The `FlowAccessActor` to use for the RPC call.
    ///   Defaults to the global `FlowActors.access` singleton for production
    ///   callers. Pass a suite-local actor in tests to avoid global state mutation.
    func sendTransaction<T: CadenceTargetType>(
        _ target: T,
        signers: [FlowSigner],
        chainID: Flow.ChainID = .mainnet,
        access: FlowAccessActor = FlowActors.access
    ) async throws -> Flow.ID {
        guard let data = Data(base64Encoded: target.cadenceBase64) else {
            throw NSError(domain: "Invalid Cadence Base64 String", code: 9_900_001)
        }

        let script = Flow.Script(data: data)

        // Empty result-builder body: no additional TransactionBuild steps.
        var tx = try await buildTransaction(
            chainID: chainID,
            skipEmptyCheck: true,
            access: access
        ) {
            // nothing
        }

        tx.script = script
        tx.arguments = target.arguments

        let signedTx = try await signTransaction(
            unsignedTransaction: tx,
            signers: signers
        )

        return try await sendTransaction(signedTransaction: signedTx, access: access)
    }
}
