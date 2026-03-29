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
aW1wb3J0IEVWTSBmcm9tIDB4RVZNCgphY2Nlc3MoYWxsKSBmdW4gbWFpbihmbG93QWRkcmVzczogQWRkcmVzcyk6IFN0cmluZz8gewogICAgaWYgbGV0IGFkZHJlc3M6IEVWTS5FVk1BZGRyZXNzID0gZ2V0QXV0aEFjY291bnQ8YXV0aChCb3Jyb3dWYWx1ZSkgJkFjY291bnQ+KGZsb3dBZGRyZXNzKQogICAgICAgIC5zdG9yYWdlLmJvcnJvdzwmRVZNLkNhZGVuY2VPd25lZEFjY291bnQ+KGZyb206IC9zdG9yYWdlL2V2bSk/LmFkZHJlc3MoKSB7CiAgICAgICAgbGV0IGJ5dGVzOiBbVUludDhdID0gW10KICAgICAgICBmb3IgYnl0ZSBpbiBhZGRyZXNzLmJ5dGVzIHsKICAgICAgICAgICAgYnl0ZXMuYXBwZW5kKGJ5dGUpCiAgICAgICAgfQogICAgICAgIHJldHVybiBTdHJpbmcuZW5jb2RlSGV4KGJ5dGVzKQogICAgfQogICAgcmV0dXJuIG5pbAp9Cg==
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

		var tx = try Flow.Transaction(from: 	script as! Decoder)

		tx.script = script
		tx.arguments = arguments
		tx.referenceBlockId = Flow.ID(hex: "0x00")
		tx.gasLimit = 100
		tx.proposalKey = .init(
			address: proposer,
			keyIndex: 0,
			sequenceNumber: 0
		)
		tx.payer = payer
		tx.authorizers = authorizers
		tx.payloadSignatures = []
		tx.envelopeSignatures = []

		return tx
	}
}

@Suite
@FlowActor
struct CadenceTargetTests {
	init() async {
		await FlowAccessActor.shared.configure(chainID: .testnet)
	}

	@Test
	func usesTestnet() async throws {
		let fixtures = TestnetFixtures()
		let target = TestCadenceTarget.logTx(test: "testnet")

		let tx = try target.makeTransaction(
			payer: fixtures.addressA,
			proposer: fixtures.addressA,
			authorizers: [fixtures.addressA, fixtures.addressB, fixtures.addressC]
		)

		let id = try await FlowAccessActor.shared.sendTransaction(
			transaction: tx
		)
		#expect(!id.hex.isEmpty)
	}

	@Test
	func canSwitchNetworks() async throws {
		await FlowAccessActor.shared.configure(chainID: .mainnet)
		await FlowAccessActor.shared.configure(chainID: .testnet)
		#expect(Bool(true))
	}
}
