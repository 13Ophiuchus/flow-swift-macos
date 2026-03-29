	//
	//  FlowParallelClientScriptsTests.swift
	//  FlowTests
	//

@testable import Flow
import Foundation
import Testing

@Suite
struct FlowParallelClientScriptsTests {

	struct MockScriptTarget: Hashable, Sendable {
		let id: Int
		let name: String

		init(id: Int, name: String) {
			self.id = id
			self.name = name
		}
	}

	actor CounterBox {
		private(set) var value: Int = 0

		func increment() {
			value += 1
		}

		func get() -> Int {
			value
		}
	}

	@Test("executeScripts returns all successful results")
	func executeScriptsReturnsResults() async throws {
		let processor = BatchProcessor()
		let targets: [MockScriptTarget] = [
			.init(id: 1, name: "A"),
			.init(id: 2, name: "B"),
			.init(id: 3, name: "C")
		]

		let results = try await processor.executeScripts(targets, maxConcurrent: 2) { target in
			ScriptExecutionResult(
				targetName: target.name,
				rawValueDescription: "result-\(target.id)"
			)
		}

		#expect(results.count == 3)
		#expect(results[.init(id: 1, name: "A")]?.targetName == "A")
		#expect(results[.init(id: 2, name: "B")]?.rawValueDescription == "result-2")
		#expect(results[.init(id: 3, name: "C")]?.rawValueDescription == "result-3")
	}

	@Test("executeScriptsSafely captures failures per target")
	func executeScriptsSafelyCapturesFailures() async throws {
		enum MockError: Error {
			case failed(Int)
		}

		let processor = BatchProcessor()
		let targets: [MockScriptTarget] = [
			.init(id: 1, name: "A"),
			.init(id: 2, name: "B"),
			.init(id: 3, name: "C")
		]

		let results = await processor.executeScriptsSafely(targets, maxConcurrent: 2) { target in
			if target.id == 2 {
				throw MockError.failed(2)
			}

			return ScriptExecutionResult(
				targetName: target.name,
				rawValueDescription: "result-\(target.id)"
			)
		}

		#expect(results.count == 3)

		if case let .success(value)? = results[.init(id: 1, name: "A")] {
			#expect(value.rawValueDescription == "result-1")
		} else {
			Issue.record("Expected success for target A")
		}

		if case .failure? = results[.init(id: 2, name: "B")] {
			#expect(true)
		} else {
			Issue.record("Expected failure for target B")
		}

		if case let .success(value)? = results[.init(id: 3, name: "C")] {
			#expect(value.rawValueDescription == "result-3")
		} else {
			Issue.record("Expected success for target C")
		}
	}

	@Test("executeScripts handles filtered targets")
	func executeScriptsHandlesFilteredTargets() async throws {
		let processor = BatchProcessor()
		let allTargets: [MockScriptTarget] = [
			.init(id: 1, name: "A"),
			.init(id: 2, name: "B"),
			.init(id: 3, name: "C"),
			.init(id: 4, name: "D")
		]

		let filtered = allTargets.filter { $0.id.isMultiple(of: 2) }

		let results = try await processor.executeScripts(filtered, maxConcurrent: 2) { target in
			ScriptExecutionResult(
				targetName: target.name,
				rawValueDescription: "result-\(target.id)"
			)
		}

		#expect(results.count == 2)
		#expect(results[.init(id: 2, name: "B")]?.targetName == "B")
		#expect(results[.init(id: 4, name: "D")]?.targetName == "D")
	}

	@Test("executeScripts respects concurrency without non-Sendable captures")
	func executeScriptsRespectsConcurrency() async throws {
		let processor = BatchProcessor()
		let counter = CounterBox()
		let targets: [MockScriptTarget] = (1...10).map { .init(id: $0, name: "T\($0)") }

		let results = try await processor.executeScripts(targets, maxConcurrent: 3) { target in
			await counter.increment()
			return ScriptExecutionResult(
				targetName: target.name,
				rawValueDescription: "result-\(target.id)"
			)
		}

		let total = await counter.get()
		#expect(results.count == 10)
		#expect(total == 10)
	}
}
