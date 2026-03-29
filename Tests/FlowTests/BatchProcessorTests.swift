import Foundation
import Testing
@testable import Flow
import _Concurrency

struct BatchProcessorTests {

	struct TestError: Error, Equatable, CustomStringConvertible, Sendable {
		let message: String
		var description: String { message }
	}

	actor ConcurrencyTracker {
		private(set) var current = 0
		private(set) var maxObserved = 0

		func begin() {
			current += 1
			if current > maxObserved {
				maxObserved = current
			}
		}

		func end() {
			current -= 1
		}

		func snapshot() -> (current: Int, maxObserved: Int) {
			(current, maxObserved)
		}
	}

	struct ScriptTarget: Hashable, Sendable {
		let id: Int
	}

	@Test
	func process_returnsEmptyDictionary_forEmptyInput() async throws {
		let sut = BatchProcessor()

		let result: [Int: String] = try await sut.process([], maxConcurrent: 4) { value in
			"value-\(value)"
		}

		#expect(result.isEmpty)
	}

	@Test
	func process_returnsAllResults_forMultipleInputs() async throws {
		let sut = BatchProcessor()

		let inputs = [1, 2, 3, 4, 5]
		let result: [Int: String] = try await sut.process(inputs, maxConcurrent: 2) { value in
			"value-\(value)"
		}

		#expect(result.count == inputs.count)
		#expect(result[1] == "value-1")
		#expect(result[2] == "value-2")
		#expect(result[3] == "value-3")
		#expect(result[4] == "value-4")
		#expect(result[5] == "value-5")
	}

	@Test
	func process_throws_whenAnyOperationFails() async {
		let sut = BatchProcessor()

		await #expect(throws: TestError.self) {
			_ = try await sut.process([1, 2, 3], maxConcurrent: 2) { value in
				if value == 2 {
					throw TestError(message: "boom")
				}
				return "value-\(value)"
			} as [Int: String]
		}
	}

	@Test
	func process_respectsMaxConcurrentLimit() async throws {
		let sut = BatchProcessor()
		let tracker = ConcurrencyTracker()

		let inputs = Array(0..<12)
		let maxConcurrent = 3

		let result: [Int: Int] = try await sut.process(inputs, maxConcurrent: maxConcurrent) { value in
			await tracker.begin()
			defer { _Concurrency.Task { await tracker.end() } }

			try await _Concurrency.Task.sleep(nanoseconds: 50_000_000)
			return value * 10
		}

		#expect(result.count == inputs.count)

		let snapshot = await tracker.snapshot()
		#expect(snapshot.current == 0)
		#expect(snapshot.maxObserved <= maxConcurrent)
	}

	@Test
	func process_withMaxConcurrentOne_behavesSerially() async throws {
		let sut = BatchProcessor()
		let tracker = ConcurrencyTracker()

		let inputs = Array(0..<5)

		let result: [Int: Int] = try await sut.process(inputs, maxConcurrent: 1) { value in
			await tracker.begin()
			defer { _Concurrency.Task { await tracker.end() } }

			try await _Concurrency.Task.sleep(nanoseconds: 20_000_000)
			return value
		}

		#expect(result.count == inputs.count)

		let snapshot = await tracker.snapshot()
		#expect(snapshot.current == 0)
		#expect(snapshot.maxObserved == 1)
	}

	@Test
	func processSafely_returnsEmptyDictionary_forEmptyInput() async {
		let sut = BatchProcessor()

		let result: [Int: Result<String, Error>] = await sut.processSafely([], maxConcurrent: 4) { value in
			"value-\(value)"
		}

		#expect(result.isEmpty)
	}

	@Test
	func processSafely_returnsPerKeyResults_forMixedSuccessAndFailure() async {
		let sut = BatchProcessor()

		let result: [Int: Result<String, Error>] = await sut.processSafely([1, 2, 3, 4], maxConcurrent: 2) { value in
			if value == 2 || value == 4 {
				throw TestError(message: "failed-\(value)")
			}
			return "value-\(value)"
		}

		#expect(result.count == 4)

		switch result[1] {
			case .success(let value)?:
				#expect(value == "value-1")
			default:
				Issue.record("Expected success for 1")
		}

		switch result[2] {
			case .failure(let error)?:
				#expect(error is TestError)
			default:
				Issue.record("Expected failure for 2")
		}

		switch result[3] {
			case .success(let value)?:
				#expect(value == "value-3")
			default:
				Issue.record("Expected success for 3")
		}

		switch result[4] {
			case .failure(let error)?:
				#expect(error is TestError)
			default:
				Issue.record("Expected failure for 4")
		}
	}

	@Test
	func processSafely_preservesAllKeys_evenWhenCompletionsAreOutOfOrder() async {
		let sut = BatchProcessor()

		let result: [Int: Result<String, Error>] = await sut.processSafely([1, 2, 3], maxConcurrent: 3) { value in
			let delay: UInt64
			switch value {
				case 1: delay = 90_000_000
				case 2: delay = 10_000_000
				default: delay = 50_000_000
			}
			try await _Concurrency.Task.sleep(nanoseconds: delay)
			return "value-\(value)"
		}

		#expect(Set(result.keys) == Set([1, 2, 3]))
	}

	@Test
	func processSafely_respectsMaxConcurrentLimit() async {
		let sut = BatchProcessor()
		let tracker = ConcurrencyTracker()

		let _: [Int: Result<Int, Error>] = await sut.processSafely(Array(0..<10), maxConcurrent: 2) { value in
			await tracker.begin()
			defer { _Concurrency.Task { await tracker.end() } }

			try await _Concurrency.Task.sleep(nanoseconds: 40_000_000)
			return value
		}

		let snapshot = await tracker.snapshot()
		#expect(snapshot.current == 0)
		#expect(snapshot.maxObserved <= 2)
	}

	@Test
	func executeScripts_returnsConcreteScriptExecutionResults() async throws {
		let sut = BatchProcessor()
		let targets = [ScriptTarget(id: 1), ScriptTarget(id: 2)]

		let result = try await sut.executeScripts(targets, maxConcurrent: 2) { target in
			ScriptExecutionResult(
				targetName: "target-\(target.id)",
				rawValueDescription: "result-\(target.id)"
			)
		}

		#expect(result.count == 2)
		#expect(result[ScriptTarget(id: 1)]?.targetName == "target-1")
		#expect(result[ScriptTarget(id: 1)]?.rawValueDescription == "result-1")
		#expect(result[ScriptTarget(id: 2)]?.targetName == "target-2")
		#expect(result[ScriptTarget(id: 2)]?.rawValueDescription == "result-2")
	}

	@Test
	func executeScriptsSafely_returnsMixedResults() async {
		let sut = BatchProcessor()
		let targets = [ScriptTarget(id: 1), ScriptTarget(id: 2), ScriptTarget(id: 3)]

		let result = await sut.executeScriptsSafely(targets, maxConcurrent: 2) { target in
			if target.id == 2 {
				throw TestError(message: "script failed")
			}

			return ScriptExecutionResult(
				targetName: "target-\(target.id)",
				rawValueDescription: "result-\(target.id)"
			)
		}

		#expect(result.count == 3)

		switch result[ScriptTarget(id: 1)] {
			case .success(let output)?:
				#expect(output.rawValueDescription == "result-1")
			default:
				Issue.record("Expected success for id 1")
		}

		switch result[ScriptTarget(id: 2)] {
			case .failure(let error)?:
				#expect(error is TestError)
			default:
				Issue.record("Expected failure for id 2")
		}

		switch result[ScriptTarget(id: 3)] {
			case .success(let output)?:
				#expect(output.rawValueDescription == "result-3")
			default:
				Issue.record("Expected success for id 3")
		}
	}

	@Test
	func sendTransactions_returnsTransactionIDsPerTarget() async throws {
		let sut = BatchProcessor()
		let targets = [ScriptTarget(id: 1), ScriptTarget(id: 2)]

		let result = try await sut.sendTransactions(targets, maxConcurrent: 2) { target in
			Flow.ID(hex: String(format: "%064x", target.id))
		}

		#expect(result.count == 2)
		#expect(result[ScriptTarget(id: 1)] != nil)
		#expect(result[ScriptTarget(id: 2)] != nil)
	}

	@Test
	func sendTransactionsSafely_returnsMixedTransactionResults() async {
		let sut = BatchProcessor()
		let targets = [ScriptTarget(id: 10), ScriptTarget(id: 20), ScriptTarget(id: 30)]

		let result = await sut.sendTransactionsSafely(targets, maxConcurrent: 2) { target in
			if target.id == 20 {
				throw TestError(message: "tx failed")
			}
			return Flow.ID(hex: String(format: "%064x", target.id))
		}

		#expect(result.count == 3)

		switch result[ScriptTarget(id: 10)] {
			case .success(let id)?:
				#expect(id.hex == String(format: "%064x", 10))
			default:
				Issue.record("Expected success for id 10")
		}

		switch result[ScriptTarget(id: 20)] {
			case .failure(let error)?:
				#expect(error is TestError)
			default:
				Issue.record("Expected failure for id 20")
		}

		switch result[ScriptTarget(id: 30)] {
			case .success(let id)?:
				#expect(id.hex == String(format: "%064x", 30))
			default:
				Issue.record("Expected success for id 30")
		}
	}
}
