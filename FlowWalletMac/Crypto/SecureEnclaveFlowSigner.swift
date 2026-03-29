//
//  SecureEnclaveFlowSigner.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


// Sources/FlowWalletMac/Crypto/SecureEnclaveFlowSigner.swift

import Foundation
import CryptoKit
import Security
import Flow

public final class SecureEnclaveFlowSigner: FlowSigner {

    private let tag: String

    public init(tag: String = "com.nic.flow.wallet.key") {
        self.tag = tag
    }

    private func loadOrCreateKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        let tagData = tag.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecSuccess,
           let key = item as? SecKey {
            return try SecureEnclave.P256.Signing.PrivateKey(secKey: key)
        }

        let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            [.privateKeyUsage],
            nil
        )!

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrAccessControl as String: access
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let secKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        return try SecureEnclave.P256.Signing.PrivateKey(secKey: secKey)
    }

    public func sign(transaction: Flow.Transaction) async throws -> Flow.Transaction {
        let key = try loadOrCreateKey()
        let payload = try transaction.canonicalPayload()
        let signature = try key.signature(for: payload)

        let sig = Flow.Transaction.Signature(
            address: transaction.proposalKey.address,
            keyIndex: transaction.proposalKey.keyIndex,
            signature: signature.derRepresentation
        )

        var signed = transaction
        signed.payloadSignatures.append(sig)
        return signed
    }
}
