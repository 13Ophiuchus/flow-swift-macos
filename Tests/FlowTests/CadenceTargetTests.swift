//
//  CadenceTargetTests.swift
//  FlowTests
//
//  Created by Hao Fu on 23/4/2025.
//  Migrated from XCTest to Swift Testing by Nicholas Reich on 2026-03-19.
//  Refactored to eliminate FlowAccessActor.shared mutation by Nicholas Reich on 2026-09-15.
//
//  Each suite owns a private TestFlowActor — the global singleton is never touched.
//

import CryptoKit
@testable import Flow
import Foundation
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
        case let .getCOAAddr(address):
            return [Flow.Argument(value: .address(address))]
        case let .logTx(test):
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
        addressA = Flow.Address(hex: "0x0000000000000001")
        addressB = Flow.Address(hex: "0x0000000000000002")
        addressC = Flow.Address(hex: "0x0000000000000003")

        let dummyKeyData = Data(repeating: 1, count: 32)
        let privateKey = try! P256.Signing.PrivateKey(rawRepresentation: dummyKeyData)

        let signer = ECDSA_P256_Signer(
            address: addressA,
            keyIndex: 0,
            privateKey: privateKey
        )
        signers = [signer]
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

// MARK: - Unit tests — no global state mutation

@Suite
struct CadenceTargetTests {
    // Suite-local actor: never touches FlowAccessActor.shared
    private let access: FlowAccessActor

    init() async {
        let a = FlowAccessActor()
        await a.configure(chainID: .testnet)
        access = a
    }

    @Test
    func usesTestnet() async throws {
        // Use a mock: the fixture signer uses a dummy, non-registered key, so a
        // real testnet node would always reject the transaction's signature.
        // This test verifies transaction construction end-to-end without
        // depending on live network state.
        let mock = MockFlowAccessAPI()
        let expectedID = Flow.ID(hex: "0xaaaaaaaa00000000000000000000000000000000000000000000000000000000")
        mock.stub_sendTransactionID = expectedID

        // Reconfigure the suite-local actor with the mock — no global mutation.
        await access.configure(chainID: .testnet, accessAPI: mock)

        let fixtures = TestnetFixtures()
        let target = TestCadenceTarget.logTx(test: "testnet")

        var tx = try target.makeTransaction(
            payer: fixtures.addressA,
            proposer: fixtures.addressA,
            authorizers: [fixtures.addressA, fixtures.addressB, fixtures.addressC]
        )
        tx.envelopeSignatures = [
            .init(address: fixtures.addressA, keyIndex: 0, signature: Data([0x01])),
        ]

        let id = try await access.sendTransaction(transaction: tx)
        #expect(id == expectedID)
    }

    @Test
    func canSwitchNetworks() async throws {
        await access.configure(chainID: .mainnet)
        await access.configure(chainID: .testnet)
        #expect(Bool(true))
    }
}

// MARK: - Isolated actor test (no global mutation)

/// Uses a suite-local FlowAccessActor — never touches FlowActors.access.
@Suite(.serialized)
@FlowActor
struct CadenceTargetIntegrationTests {
    private let access: FlowAccessActor
    private let mock: MockFlowAccessAPI

    init() async {
        let m = MockFlowAccessAPI()
        let a = FlowAccessActor(initialChainID: .testnet)
        await a.configure(chainID: .testnet, accessAPI: m)
        mock = m
        access = a
    }

    @Test
    func usesTestnetViaContext() async throws {
        let expectedID = Flow.ID(hex: "0xaaaaaaaa00000000000000000000000000000000000000000000000000000000")
        mock.stub_sendTransactionID = expectedID

        let fixtures = TestnetFixtures()
        let target = TestCadenceTarget.logTx(test: "testnet")

        var tx = try target.makeTransaction(
            payer: fixtures.addressA,
            proposer: fixtures.addressA,
            authorizers: [fixtures.addressA, fixtures.addressB, fixtures.addressC]
        )
        tx.envelopeSignatures = [
            .init(address: fixtures.addressA, keyIndex: 0, signature: Data([0x01])),
        ]

        let id = try await access.sendTransaction(transaction: tx)
        #expect(id == expectedID)
    }
}
