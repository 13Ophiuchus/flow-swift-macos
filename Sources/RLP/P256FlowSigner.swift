	//
	//  P256FlowSigner.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/21/26.
	//

import Foundation
import CryptoSwift
#if canImport(CryptoKit)
#if canImport(CryptoKit)
#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif
#else
import Crypto
#endif
#endif







// MARK: - P256 signer

#if canImport(CryptoKit)

/// ECDSA P‑256 signer for Flow, backed by CryptoKit.
public struct P256FlowSigner: FlowSigner {

	public let algorithm: Flow.SignatureAlgorithm = .ECDSA_P256
	public let address: Flow.Address
	public let keyIndex: Int

	private let key: P256.Signing.PrivateKey

	public init(
		key: P256.Signing.PrivateKey,
		address: Flow.Address,
		keyIndex: Int
	) {
		self.key = key
		self.address = address
		self.keyIndex = keyIndex
	}

	public func sign(
		signableData: Data,
		transaction: Flow.Transaction?
	) async throws -> Data {
			// Flow requires SHA3-256 as the pre-image hash before ECDSA
			// signing. CryptoKit's `signature(for: Data)` hashes with SHA-256
			// by default, which the access node always rejects — we hash with
			// SHA3-256 ourselves via CryptoSwift and sign the raw digest by
			// wrapping it in a type conforming to CryptoKit's `Digest`.
		let digestBytes = signableData.bytes.sha3(.sha256)
		let digest = SHA3RawDigest(bytes: digestBytes)
		let signature = try key.signature(for: digest)
			// Flow expects the raw, fixed-length r||s (P1363) signature format,
			// not DER — derRepresentation was producing signatures the access
			// node would reject as invalid.
		return signature.rawRepresentation
	}
}

/// Minimal wrapper so a pre-computed SHA3-256 digest can be passed to
/// CryptoKit's `P256.Signing.PrivateKey.signature(for: some Digest)`,
/// bypassing CryptoKit's automatic (and Flow-incompatible) SHA-256 hashing.
struct SHA3RawDigest: CryptoKit.Digest {
	typealias Element = UInt8

	static var byteCount: Int { 32 }

	private let storage: [UInt8]

	init(bytes: [UInt8]) {
		precondition(bytes.count == Self.byteCount, "SHA3-256 digest must be 32 bytes")
		self.storage = bytes
	}

	func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
		try storage.withUnsafeBytes(body)
	}

	func makeIterator() -> Array<UInt8>.Iterator {
		storage.makeIterator()
	}

	var description: String {
		storage.map { String(format: "%02x", $0) }.joined()
	}

	static func == (lhs: SHA3RawDigest, rhs: SHA3RawDigest) -> Bool {
		lhs.storage == rhs.storage
	}

	func hash(into hasher: inout Hasher) {
		hasher.combine(storage)
	}
}

#endif
