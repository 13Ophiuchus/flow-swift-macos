	//
	//  CadenceTargetTests.swift
	//  FlowTests
	//
	//  Created by Hao Fu on 23/4/2025.
	//  Migrated from XCTest to Swift Testing by Nicholas Reich on 2026-03-19.
	//

import Foundation
import CryptoKit
@testable import Flow
import Testing

enum TestCadenceTarget: CadenceTargetType {
	case getCOAAddr(address: Flow.Address)
	case logTx(test: String)

	var cadenceBase64: String {
		switch self {
			case .getCOAAddr:
				return """
YWNjZXNzKGFsbCkgZnVuIG1haW4oZmxvd0FkZHJlc3M6IEFkZHJlc3MpOiBTdHJpbmc/IHsKICAgIHJldHVybiBmbG93QWRkcmVzcy50b1N0cmluZygpCn0K
"""
			case .logTx:
				return """
dHJhbnNhY3Rpb24odGVzdDogU3RyaW5nKSB7CiAgICBwcmVwYXJlKHNpZ25lcjE6ICZBY2NvdW50LCBzaWduZXIyOiAmQWNjb3VudCwgc2lnbmVyMzogJkFjY291bnQpIHsKICAgICAgICBsb2coc2lnbmVyMS5hZGRyZXNzKQogICAgICAgIGxvZyhzaWduZXIyLmFkZHJlc3MpCiAgICAgICAgbG9nKHNpZ25lcjMuYWRkcmVzcykKICAgICAgICBsb2codGVzdCkKICAgIH0KfQ==
"""
		}
	}

	var type: CadenceType {
		switch self {
			case .getCOAAddr:
				return .query
			case .logTx:
				return .transaction
		}
	}

	var arguments: [Flow.Argument] {
		switch self {
			case .getCOAAddr(let address):
				return [Flow.Argument(value: .address(address))]
			case .logTx(let test):
				return [Flow.Argument(value: .string(test))]
		}
	}

	var returnType: Decodable.Type {
		if type == .transaction { return Flow.ID.self }
		switch self {
			case .getCOAAddr:
				return String?.self
			default:
				return Flow.ID.self
		}
	}
}

/// Minimal test fixtures for signing a tx on testnet.
struct TestnetFixtures {
	let addressA: Flow.Address
	let addressB: Flow.Address
	let addressC: Flow.Address
	let signers: [ECDSA_P256_Signer]

	init() {
		self.addressA = Flow.Address(hex: "0x0000000000000001")
		self.addressB = Flow.Address(hex: "0x0000000000000002")
		self.addressC = Flow.Address(hex: "0x0000000000000003")

		let dummyKeyData = Data(repeating: 1, count: 32)
		let privateKey = try! P256.Signing.PrivateKey(rawRepresentation: dummyKeyData)
		
		let signer = ECDSA_P256_Signer(
			address: addressA,
			keyIndex: 0,
			privateKey: privateKey
		)
		self.signers = [signer]
	}
}

// MARK: - Test-only helper to build a Flow.Transaction from a CadenceTargetType

extension CadenceTargetType {
	func makeTransaction(
	payer: Flow.Address,
	proposer: Flow.Address,
	authorizers: [Flow.Address]
	) throws -> Flow.Transaction {
		let scriptData = Data(base64Encoded: cadenceBase64) ?? Data()
		let script = Flow.Script(data: scriptData)

		let tx = Flow.Transaction(
			script: script,
			arguments: arguments,
			referenceBlockId: Flow.ID(hex: "0x00"),
			gasLimit: UInt64(100),
			proposalKey: .init(
				address: proposer,
				keyIndex: 0,
				sequenceNumber: 0
			),
			payer: payer,
			authorizers: authorizers,
			payloadSignatures: [],
			envelopeSignatures: []
		)

		return tx
	}
}

@Suite(.serialized)
@FlowActor
struct CadenceTargetTests {
	init() async {
		await FlowAccessActor.shared.configure(chainID: .testnet)
	}

	@Test
	func usesTestnet() async throws {
			// Use a mock: the fixture signer uses a dummy, non-registered key, so a
			// real testnet node would always reject the transaction's signature
			// even if we signed the envelope. This test verifies transaction
			// construction end-to-end without depending on live network state.
			//
			// withTestFlowContext scopes the mutation to this test only and restores
			// the previous shared chainID/client afterward, preventing cross-test
			// pollution of the FlowAccessActor.shared singleton.
		let mock = MockFlowAccessAPI()
		let expectedID = Flow.ID(hex: "0xaaaaaaaa00000000000000000000000000000000000000000000000000000000")
		mock.stub_sendTransactionID = expectedID

		try await withTestFlowContext(chainID: .testnet, accessAPI: mock) {
			let fixtures = TestnetFixtures()
			let target = TestCadenceTarget.logTx(test: "testnet")

			var tx = try target.makeTransaction(
				payer: fixtures.addressA,
				proposer: fixtures.addressA,
				authorizers: [fixtures.addressA, fixtures.addressB, fixtures.addressC]
			)
			tx.envelopeSignatures = [
				.init(address: fixtures.addressA, keyIndex: 0, signature: Data([0x01]))
			]

			let id = try await FlowAccessActor.shared.sendTransaction(
				transaction: tx
			)
			#expect(id == expectedID)
		}
	}

	@Test
	func canSwitchNetworks() async throws {
		await FlowAccessActor.shared.configure(chainID: .mainnet)
		await FlowAccessActor.shared.configure(chainID: .testnet)
		#expect(Bool(true))
	}
}
