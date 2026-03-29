	//
	//  FlowAddressLoader.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 2026-03-26.
	//

import Foundation

	/// JSON file containing a flat list of account or contract addresses.
public struct FlowAddressListFile: Decodable {
	public let addresses: [String]
}

	/// JSON file containing contract name -> address mappings per network.
public struct FlowContractAddressMapFile: Decodable {

	public struct NetworkMap: Decodable {
		public let mainnet: [String: String]?
		public let testnet: [String: String]?
		public let emulator: [String: String]?
		public let custom: [String: [String: String]]?
	}

	public let contracts: NetworkMap
}

/// Loader utilities for addresses and contract maps.
public enum FlowAddressLoader {

		// MARK: - Raw address lists

	public static func loadAddressList(from url: URL) throws -> [Flow.Address] {
		let data = try Data(contentsOf: url)
		let decoder = JSONDecoder()
		let decoded: FlowAddressListFile = try decoder.decode(FlowAddressListFile.self, from: data)
		return decoded.addresses.compactMap { Flow.Address(hex: $0) }
	}

	public static func loadAddressList(fromPath path: String) throws -> [Flow.Address] {
		try loadAddressList(from: URL(fileURLWithPath: path))
	}

		// MARK: - Contract address maps

		/// Load a contract-address mapping JSON and populate a ContractAddressRegister.
	public static func loadContractMap(
		from url: URL,
		into register: ContractAddressRegister
	) throws {
		let data = try Data(contentsOf: url)
		let decoder = JSONDecoder()
		let decoded: FlowContractAddressMapFile = try decoder.decode(
			FlowContractAddressMapFile.self,
			from: data
		)

		if let mainnet = decoded.contracts.mainnet {
			for (name, addr) in mainnet {
				register.setAddress(addr, for: name, on: .mainnet)
			}
		}

		if let testnet = decoded.contracts.testnet {
			for (name, addr) in testnet {
				register.setAddress(addr, for: name, on: .testnet)
			}
		}

		if let emulator = decoded.contracts.emulator {
			for (name, addr) in emulator {
				register.setAddress(addr, for: name, on: .emulator)
			}
		}

		if let customNetworks = decoded.contracts.custom {
			for (networkName, map) in customNetworks {
					// Build a gRPC transport using Flow.Transport
				let endpoint = Flow.Transport.Endpoint(node: "localhost", port: 3569)
				let transport: Flow.Transport = .gRPC(endpoint)

					// NOTE: label is transport:, not endpoint:
				let chainID = Flow.ChainID.custom(name: networkName, transport: transport)

				for (name, addr) in map {
					register.setAddress(addr, for: name, on: chainID)
				}
			}
		}

	}

	public static func loadContractMap(
		fromPath path: String,
		into register: ContractAddressRegister
	) throws {
		try loadContractMap(from: URL(fileURLWithPath: path), into: register)
	}
}
