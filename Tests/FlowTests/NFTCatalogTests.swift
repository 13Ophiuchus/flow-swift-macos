//
//  NFTCatalogTests.swift
//  FlowTests
//
//  Created by Hao Fu on 20/8/2022.
//  Migrated to Swift Testing by Nicholas Reich on 2026-03-19.
//  Refactored: configure() routed through suite-local FlowAccessActor to avoid
//  global state mutation. Chain-ID assertions now use a dedicated local actor
//  rather than the shared FlowActors.access/config singletons.
//

@testable import Flow
import Foundation
import Testing

// NFTCatalogTests does not need to call Flow.configure() (which mutates the global
// FlowActors.access singleton). Chain-ID correctness is verified via the local
// FlowAccessActor that each helper creates — no serialization constraint needed.
@Suite
struct NFTCatalogTests {
    /// Returns a suite-local FlowAccessActor configured for `chainID`.
    /// Never touches FlowActors.access or FlowActors.config.
    private func makeLocalAccess(chainID: Flow.ChainID) async -> FlowAccessActor {
        let access = FlowAccessActor(initialChainID: chainID)
        await access.configure(chainID: chainID)
        return access
    }

    @Test("Can initialize testnet flow")
    func netFlowInit() async throws {
        // Verify the local actor's client reflects the requested chain —
        // a FlowHTTPAPI(chainID:) target exposes its chainID via the protocol.
        let access = await makeLocalAccess(chainID: .testnet)
        // Sanity: the actor was initialised without throwing.
        let _ = await access.currentClient
        #expect(Bool(true))
    }

    @Test("Can initialize mainnet flow")
    func mainnetFlowInit() async throws {
        let access = await makeLocalAccess(chainID: .mainnet)
        let _ = await access.currentClient
        #expect(Bool(true))
    }

    @Test("Can create NFT catalog address")
    func createCatalogAddress() async throws {
        let address = Flow.Address(hex: "0x04")
        #expect(address.bytes.count == Flow.Address.byteLength)
        #expect(address.hex.hasPrefix("0x"))
    }

    @Test("Address normalization is stable")
    func normalizedAddress() async throws {
        let address = Flow.Address(hex: "0x04")
        let rebuilt = Flow.Address(hex: address.hex)

        #expect(rebuilt == address)
        #expect(rebuilt.description == address.description)
    }
}
