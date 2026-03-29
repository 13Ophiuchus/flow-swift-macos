	//
	//  FlowActor.swift
	//  Flow
	//
	//  Created by Nicholas Reich on 3/22/26.
	//

import Foundation

	/// Global actor used to isolate high-level Flow façade APIs.
@globalActor
struct FlowActor {
	static let shared = FlowActorImpl()
}

actor FlowActorImpl {
	func run<R>(_ operation: @Sendable @escaping () async throws -> R) async rethrows -> R {
		try await operation()
	}
}


