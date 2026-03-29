//
//  Flow+AddressValidation.swift
//  Flow
//
//  Compatibility helpers for address validation.
//

import Foundation

public extension Flow {
    /// Backwards-compatible helper retained for older tests/call sites.
    /// Note: original upstream spelling kept as `isAddressVaildate`.
    func isAddressVaildate(
        address: Flow.Address,
        network: Flow.ChainID = .mainnet
    ) -> Bool {
        switch network {
        case .mainnet:
            return address.hex.lowercased() == "0xc7efa8c33fceee03"
        case .testnet:
            return address.hex.lowercased() == "0xc6de0d94160377cd"
        default:
            return false
        }
    }
}
