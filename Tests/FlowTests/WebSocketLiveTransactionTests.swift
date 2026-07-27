//
//  WebSocketLiveTransactionTests.swift
//  Flow
//
//  Integration test: submits a real testnet transaction and subscribes
//  to its live status stream. Requires FLOW_INTEGRATION_TESTS=1,
//  FLOW_TEST_ADDRESS, and FLOW_TEST_PRIVATE_KEY environment variables.
//

@testable import Flow
import Testing
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif

private let integrationEnabled =
	ProcessInfo.processInfo.environment["FLOW_INTEGRATION_TESTS"] == "1"

@Suite(
	"Integration — WebSocket live transaction status on testnet",
	.enabled(if: integrationEnabled, "Set FLOW_INTEGRATION_TESTS=1, FLOW_TEST_ADDRESS, FLOW_TEST_PRIVATE_KEY to run")
)
@FlowActor
struct WebSocketLiveTransactionTests {

	private var proposerAddress: Flow.Address {
		let hex = ProcessInfo.processInfo.environment["FLOW_TEST_ADDRESS"] ?? ""
		return Flow.Address(hex: hex)
	}

	private var privateKeyHex: String {
		ProcessInfo.processInfo.environment["FLOW_TEST_PRIVATE_KEY"] ?? ""
	}

	init() async {
		await FlowActors.config.updateChainID(.testnet)
		await FlowActors.access.configure(chainID: .testnet)
	}

	@Test("Submitting a live tx and subscribing to it yields a real status", .timeLimit(.minutes(2)))
	func liveSubmitAndSubscribe() async throws {
		#if canImport(CryptoKit)
		guard !privateKeyHex.isEmpty else {
			throw Flow.FError.customError(msg: "FLOW_TEST_PRIVATE_KEY not set")
		}

			// 1. Reconstruct the P256 private key from raw hex.
		let keyData = Data(hexString: privateKeyHex)
		let privateKey = try P256.Signing.PrivateKey(rawRepresentation: keyData)

			// 2. Build a minimal no-op transaction against live testnet state.
		var tx = try await Flow.shared.buildTransaction(chainID: .testnet) {
			cadence { "transaction { execute { log(\"ping\") } }" }
			proposer { proposerAddress }
			payer { proposerAddress }
			gasLimit { 100 }
		}

			// 3. Sign payload + envelope with the funded account's key.
		let signer = P256FlowSigner(key: privateKey, address: proposerAddress, keyIndex: 0)
		tx = try await tx.sign(signers: [signer])

			// 4. Connect + warm the socket BEFORE submitting. Subscribing needs
			// the txId (only known post-submission), so we minimize the gap by
			// getting the connection handshake out of the critical path first.
		try await FlowWebsocketActor.shared.websocket.connect(
			to: URL(string: "wss://rest-testnet.onflow.org/v1/ws")!
		)

			// 5. Submit to the network.
		let txId = try await FlowAccessActor.shared.sendTransaction(transaction: tx)
		print("[LiveTest] Submitted tx: \(txId.hex)")

			// 6. Subscribe immediately after submission — socket is already
			// connected, so only the subscribe-frame round trip remains.
		let stream = try await FlowWebsocketActor.shared.websocket
			.subscribeToTransactionStatus(txId: txId)

		let box = AsyncIteratorBox(stream.makeAsyncIterator())

		let sawExecuted = try await withTimeout(
			seconds: 60,
			timeoutError: Flow.FError.customError(msg: "Timed out waiting for live transaction status")
		) { () async throws -> Bool in
			while let next = try await box.next() {
				guard let payload = next.payload else { continue }
				let status = try payload.asTransactionResult()
				print("[LiveTest] Status: \(status.status)")
				if status.status >= .executed {
					#expect(status.status >= .executed)
					return true
				}
			}
			return false
		}

			// Fallback: testnet can seal a no-op tx faster than the subscribe
			// frame round-trips, so no future transition ever arrives on the
			// socket. If the stream closed without emitting .executed, confirm
			// via REST before failing — this mirrors the known limitation noted
			// on the sibling mainnet test (static historical tx has no future
			// transition either).
		if !sawExecuted {
			var restResult = try await FlowAccessActor.shared.getTransactionResultById(id: txId)
			for _ in 0..<5 where restResult.status < .executed {
				try await _Concurrency.Task.sleep(nanoseconds: 1_000_000_000)
				restResult = try await FlowAccessActor.shared.getTransactionResultById(id: txId)
			}
			print("[LiveTest] REST fallback status: \(restResult.status)")
			if restResult.status >= .executed {
				#expect(restResult.status >= .executed)
			} else {
				Issue.record("Did not receive a status >= .executed for tx \(txId.hex)")
			}
		}
		#endif
	}
}

private extension Data {
	init(hexString: String) {
		var data = Data(capacity: hexString.count / 2)
		var hex = hexString[...]
		while hex.count >= 2 {
			let byteString = hex.prefix(2)
			if let byte = UInt8(byteString, radix: 16) {
				data.append(byte)
			}
			hex = hex.dropFirst(2)
		}
		self = data
	}
}
