//
//  FlowAddressesFile.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


//
//  FlowAddressesLoader.swift
//  Flow
//

import Foundation

public struct FlowAddressesFile: Decodable {
    public let addresses: [String]
}

public enum FlowAddressesLoader {

    /// Load addresses.json from a file URL.
    public static func load(from url: URL) throws -> [Flow.Address] {
        let data = try Data(contentsOf: url)
        let decoded = try JSONDecoder().decode(FlowAddressesFile.self, from: data)
        return decoded.addresses.compactMap { Flow.Address(hex: $0) }
    }

    /// Load addresses.json from a path on disk.
    public static func load(fromPath path: String) throws -> [Flow.Address] {
        try load(from: URL(fileURLWithPath: path))
    }
}
