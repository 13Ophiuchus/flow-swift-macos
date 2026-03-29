	//
	//  FlowCryptoActor.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/23/26.
	//


import Foundation

public actor FlowCryptoActor {
	public static let shared = FlowCryptoActor()

	public init() {}

		// future: signing, key management, secure enclave ops…
}

	/// Global actor for cryptographic operations.
@globalActor
public enum FlowCrypto {
	public nonisolated static let shared = FlowCryptoActor.shared
}
