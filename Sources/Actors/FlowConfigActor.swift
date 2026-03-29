//
//  FlowConfigActor.swift
//  Flow
//
//  Created by Nicholas Reich on 3/21/26.
//


//
//  FlowConfigActor.swift
//

	// FlowConfigActor.swift

public actor FlowConfigActor: Sendable {
	public static let shared = FlowConfigActor()

	public private(set) var chainID: Flow.ChainID = .mainnet

	public init() {}

	public func updateChainID(_ newValue: Flow.ChainID) {
		chainID = newValue
	}
}
