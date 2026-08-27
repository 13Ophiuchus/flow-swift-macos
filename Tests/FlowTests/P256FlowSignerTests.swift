//
//  P256FlowSignerTests.swift
//  FlowTests
//
//  Unit tests for P256FlowSigner's SHA3-256 pre-hash + raw (P1363)
//  signature format, which Flow's access nodes require instead of
//  CryptoKit's default SHA-256 + DER signature encoding.
//

@testable import Flow
import Testing
import Foundation
import CryptoSwift
#if canImport(CryptoKit)
import CryptoKit
#endif

#if canImport(CryptoKit)

@Suite("P256FlowSigner — SHA3-256 pre-hash and raw signature format")
struct P256FlowSignerTests {

	@Test("Produces a raw (P1363) signature of the correct fixed length")
	func rawSignatureLength() async throws {
		let privateKey = P256.Signing.PrivateKey()
		let signer = P256FlowSigner(
			key: privateKey,
			address: Flow.Address(hex: "0x0000000000000001"),
			keyIndex: 0
		)

		let message = Data("ping".utf8)
		let signatureData = try await signer.sign(signableData: message, transaction: nil)

			// P256 raw (P1363) signatures are exactly 64 bytes: 32-byte r || 32-byte s.
			// DER-encoded signatures vary in length (typically 70-72 bytes) and are
			// therefore distinguishable from this fixed-length check.
		#expect(signatureData.count == 64)
	}

	@Test("Signs the SHA3-256 digest of the input, not the raw SHA-256 digest")
	func signsSHA3256Digest() async throws {
		let privateKey = P256.Signing.PrivateKey()
		let signer = P256FlowSigner(
			key: privateKey,
			address: Flow.Address(hex: "0x0000000000000001"),
			keyIndex: 0
		)

		let message = Data("ping".utf8)
		let signatureData = try await signer.sign(signableData: message, transaction: nil)

		let expectedDigestBytes = message.bytes.sha3(.sha256)
		let expectedDigest = SHA3RawDigest(bytes: expectedDigestBytes)

		let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)

			// If the signer had hashed with SHA-256 (CryptoKit's default) instead
			// of SHA3-256, this verification against the SHA3-256 digest would fail.
		#expect(privateKey.publicKey.isValidSignature(ecdsaSignature, for: expectedDigest))
	}

	@Test("Signature verifies against the correct public key and rejects tampered data")
	func signatureVerifiesCorrectly() async throws {
		let privateKey = P256.Signing.PrivateKey()
		let wrongKey = P256.Signing.PrivateKey()
		let signer = P256FlowSigner(
			key: privateKey,
			address: Flow.Address(hex: "0x0000000000000001"),
			keyIndex: 0
		)

		let message = Data("transaction-payload".utf8)
		let signatureData = try await signer.sign(signableData: message, transaction: nil)
		let ecdsaSignature = try P256.Signing.ECDSASignature(rawRepresentation: signatureData)

		let digestBytes = message.bytes.sha3(.sha256)
		let digest = SHA3RawDigest(bytes: digestBytes)

		#expect(privateKey.publicKey.isValidSignature(ecdsaSignature, for: digest))
		#expect(!wrongKey.publicKey.isValidSignature(ecdsaSignature, for: digest))

		let tamperedDigestBytes = Data("different-payload".utf8).bytes.sha3(.sha256)
		let tamperedDigest = SHA3RawDigest(bytes: tamperedDigestBytes)
		#expect(!privateKey.publicKey.isValidSignature(ecdsaSignature, for: tamperedDigest))
	}

	@Test("Reports the ECDSA_P256 signature algorithm")
	func reportsCorrectAlgorithm() {
		let privateKey = P256.Signing.PrivateKey()
		let signer = P256FlowSigner(
			key: privateKey,
			address: Flow.Address(hex: "0x0000000000000001"),
			keyIndex: 0
		)
		#expect(signer.algorithm == .ECDSA_P256)
	}
}

#endif
