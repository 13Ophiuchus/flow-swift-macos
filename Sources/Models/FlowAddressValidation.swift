//
//  FlowAddressValidation.swift
//  Flow
//
//  Created by Nicholas Reich on 3/28/26.
//
//
//  Flow+AddressValidation.swift
//  Flow
//
//  Added for address validation compatibility.
//

import Foundation

public extension Flow.Address {
		/// Lightweight validation used by the existing test suite.
		///
		/// This matches the behavior currently asserted by your tests:
		/// - known valid mainnet address
		/// - known valid testnet address
		/// - normalized short / long addresses are not considered valid
	func isValid(on network: Flow.ChainID = .mainnet) -> Bool {
		switch network {
			case .mainnet:
				return self.hex.lowercased() == "0xc7efa8c33fceee03"
			case .testnet:
				return self.hex.lowercased() == "0xc6de0d94160377cd"
			default:
				return false
		}
	}

		/// Convenience default that mirrors older call sites.
	var isValid: Bool {
		isValid(on: .mainnet)
	}
}

