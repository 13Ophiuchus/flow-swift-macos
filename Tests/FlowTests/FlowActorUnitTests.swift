//
//  FlowActorUnitTests.swift
//  FlowTests
//
//  Unit tests: zero network calls. Each suite that needs a FlowAccessActor
//  creates its own isolated instance via FlowAccessActor(initialChainID:)
//  and passes it explicitly to buildTransaction/sendTransaction via the
//  `access:` parameter. The global FlowActors.access singleton is never
//  mutated, so suites run safely in parallel with no race conditions.
//

@testable import BigInt
@testable import Flow
import Foundation
import Testing

// MARK: - Shared test fixtures

private let testAddress = Flow.Address(hex: "0x7e60df042a9c0868")
private let testBlockID = Flow.ID(hex: "0xdeadbeef00000000000000000000000000000000000000000000000000000000")

// MARK: - FlowConfigActor

@Suite("FlowConfigActor — chain ID management", .serialized)
struct FlowConfigActorTests {
    @Test("Default chain is mainnet")
    func defaultChainIsMainnet() async {
        let actor = FlowConfigActor()
        await #expect(actor.chainID == .mainnet)
    }

    @Test("updateChainID persists the new value")
    func updateChainID() async {
        let actor = FlowConfigActor()
        await actor.updateChainID(.testnet)
        await #expect(actor.chainID == .testnet)
    }

    @Test("Shared instance is accessible")
    func sharedInstance() async {
        let chainID = await FlowConfigActor.shared.chainID
        #expect(chainID == .mainnet || chainID == .testnet)
    }
}

// MARK: - FlowAccessActor

@Suite("FlowAccessActor — mock-injected API calls", .serialized)
@FlowActor
struct FlowAccessActorTests {
    // Suite-local actor — never touches FlowActors.access
    private let access: FlowAccessActor
    private let mock: MockFlowAccessAPI

    init() async {
        let m = MockFlowAccessAPI()
        let a = FlowAccessActor(initialChainID: .testnet)
        await a.configure(chainID: .testnet, accessAPI: m)
        mock = m
        access = a
    }

    @Test("ping returns mock value")
    func ping() async throws {
        mock.stub_ping = true
        let result = try await access.ping()
        #expect(result == true)
        #expect(mock.callCount_ping == 1)
    }

    @Test("ping propagates thrown error")
    func pingThrows() async {
        mock.stub_error = MockError.intentional("ping failure")
        do {
        _ = try await access.ping()
            Issue.record("Expected MockError to be thrown — but no error was thrown")
        } catch {
            #expect(error is MockError)
        }
    }

    @Test("executeScriptAtLatestBlock returns stub response")
    func executeScript() async throws {
        mock.stub_scriptResponse = Flow.ScriptResponse(
            data: #"{"type":"String","value":"hello"}"#.data(using: .utf8)!
        )
        let response = try await access.executeScriptAtLatestBlock(
            script: Flow.Script(text: "access(all) fun main(): String { return \"hello\" }"),
            arguments: [],
            blockStatus: Flow.BlockStatus.final
        )
        let decoded: String = try response.decode()
        #expect(decoded == "hello")
        #expect(mock.callCount_executeScriptAtLatestBlock == 1)
    }

    @Test("getAccountAtLatestBlock returns stub account")
    func getAccount() async throws {
        mock.stub_account = MockFlowAccessAPI.makeAccount(
            address: testAddress.hex,
            sequenceNumber: 7
        )
        let account = try await access.getAccountAtLatestBlock(
            address: testAddress,
            blockStatus: Flow.BlockStatus.final
        )
        #expect(account.address == testAddress)
        #expect(account.keys.first?.sequenceNumber == 7)
    }

    @Test("sendTransaction returns stub ID")
    func sendTransaction() async throws {
        mock.stub_sendTransactionID = testBlockID
        let dummyTx = try makeDummyTransaction()
        let id = try await access.sendTransaction(transaction: dummyTx)
        #expect(id == testBlockID)
        #expect(mock.callCount_sendTransaction == 1)
    }

    @Test("Error from API surfaces through actor")
    func errorPropagates() async {
        mock.stub_error = Flow.FError.customError(msg: "test error")
        do {
        _ = try await access.executeScriptAtLatestBlock(
            script: Flow.Script(text: ""),
            arguments: [],
            blockStatus: Flow.BlockStatus.final
        )
            Issue.record("Expected Flow.FError to be thrown — but no error was thrown")
        } catch {
            #expect(error is Flow.FError)
        }
    }
}

// MARK: - TransactionBuild DSL (pure, no actor needed)

@Suite("TransactionBuild DSL — pure value type tests", .serialized)
struct TransactionBuildDSLTests {
    @Test("cadence() wraps script text")
    func cadenceBuilder() {
        let build = cadence { "access(all) fun main() {}" }
        if case let .script(script) = build {
            #expect(script.text == "access(all) fun main() {}")
        } else {
            Issue.record("Expected .script case")
        }
    }

    @Test("arguments() wraps FValue array")
    func argumentsBuilder() {
        let build = arguments { [.string("hello"), .int(42)] as [Flow.Cadence.FValue] }
        if case let .argument(args) = build {
            #expect(args.count == 2)
        } else {
            Issue.record("Expected .argument case")
        }
    }

    @Test("payer() wraps address string")
    func payerBuilder() {
        let build = payer { testAddress.hex }
        if case let .payer(address) = build {
            #expect(address == testAddress)
        } else {
            Issue.record("Expected .payer case")
        }
    }

    @Test("proposer() wraps address string")
    func proposerBuilder() {
        let build = proposer { testAddress.hex }
        if case let .proposer(key) = build {
            #expect(key.address == testAddress)
            #expect(key.keyIndex == 0)
        } else {
            Issue.record("Expected .proposer case")
        }
    }

    @Test("gasLimit() wraps Int")
    func gasLimitBuilder() {
        let build = gasLimit { 1000 }
        if case let .gasLimit(limit) = build {
            #expect(limit == BigUInt(1000))
        } else {
            Issue.record("Expected .gasLimit case")
        }
    }

    @Test("Result builder composes multiple components")
    func resultBuilderComposition() {
        @Flow.TransactionBuild.TransactionBuilder
        func buildComponents() -> [Flow.TransactionBuild] {
            cadence { "access(all) fun main() {}" }
            // Disambiguate: annotate the empty array so Swift picks the right overload.
            arguments { [Flow.Argument]() }
            payer { testAddress.hex }
            proposer { testAddress.hex }
            gasLimit { 9999 }
        }
        let components = buildComponents()
        #expect(components.count == 5)
    }
}

// MARK: - buildTransaction (FlowActor-isolated, suite-local actor)

@Suite("Flow.buildTransaction — mock-injected, no network", .serialized)
@FlowActor
struct BuildTransactionTests {
    // Suite-local actor — never touches FlowActors.access
    private let access: FlowAccessActor
    private let mock: MockFlowAccessAPI

    init() async {
        let m = MockFlowAccessAPI()
        m.stub_latestBlock = MockFlowAccessAPI.makeBlock()
        m.stub_account = MockFlowAccessAPI.makeAccount(
            address: testAddress.hex,
            sequenceNumber: 1
        )
        let a = FlowAccessActor(initialChainID: .testnet)
        await a.configure(chainID: .testnet, accessAPI: m)
        mock = m
        access = a
    }

    @Test("buildTransaction resolves reference block from mock")
    func buildsTransactionWithMockBlock() async throws {
        let tx = try await Flow.shared.buildTransaction(
            chainID: .testnet,
            access: access
        ) {
            cadence { "access(all) fun main() {}" }
            proposer { testAddress.hex }
            payer { testAddress.hex }
            authorizers { testAddress }
            gasLimit { 100 }
        }
        #expect(tx.referenceBlockId == Flow.ID(hex: MockFlowAccessAPI.makeBlock().id.hex))
        #expect(tx.proposalKey.address == testAddress)
        #expect(tx.proposalKey.sequenceNumber == 1)
    }

    @Test("buildTransaction propagates emptyProposer error")
    func missingProposerThrows() async {
        do {
        _ = try await Flow.shared.buildTransaction(
            chainID: .testnet,
            access: access
        ) {
            cadence { "access(all) fun main() {}" }
            payer { testAddress.hex }
        }
            Issue.record("Expected Flow.FError to be thrown — but no error was thrown")
        } catch {
            #expect(error is Flow.FError)
        }
    }

    @Test("buildTransaction propagates invalidScript error")
    func emptyScriptThrows() async {
        do {
        _ = try await Flow.shared.buildTransaction(
            chainID: .testnet,
            access: access
        ) {
            cadence { "" }
            proposer { testAddress.hex }
            payer { testAddress.hex }
        }
            Issue.record("Expected Flow.FError to be thrown — but no error was thrown")
        } catch {
            #expect(error is Flow.FError)
        }
    }

    @Test("skipEmptyCheck allows empty script")
    func skipEmptyCheckAllowsEmptyScript() async throws {
        let tx = try await Flow.shared.buildTransaction(
            chainID: .testnet,
            skipEmptyCheck: true,
            access: access
        ) {
            cadence { "" }
            proposer { testAddress.hex }
            payer { testAddress.hex }
        }
        #expect(tx.script.text == "")
    }

    @Test("sendTransaction calls API with signed transaction")
    func sendTransactionCallsAPI() async throws {
        mock.stub_sendTransactionID = testBlockID
        let dummyTx = try makeDummyTransaction()
        let id = try await Flow.shared.sendTransaction(
            chainID: .testnet,
            signedTransaction: dummyTx,
            access: access
        )
        #expect(id == testBlockID)
    }

    @Test("resolveProposalKey fetches sequence number from account")
    func resolveProposalKeyFetchesSequenceNumber() async throws {
        mock.stub_account = MockFlowAccessAPI.makeAccount(
            address: testAddress.hex,
            sequenceNumber: 99
        )
        let tx = try await Flow.shared.buildTransaction(
            chainID: .testnet,
            access: access
        ) {
            cadence { "access(all) fun main() {}" }
            proposer { testAddress.hex }
            payer { testAddress.hex }
        }
        #expect(tx.proposalKey.sequenceNumber == 99)
        #expect(mock.callCount_getAccountAtLatestBlock >= 1)
    }
}

// MARK: - FlowCryptoActor

@Suite("FlowCryptoActor — actor isolation", .serialized)
struct FlowCryptoActorTests {
    @Test("Shared instance is the same object")
    func sharedInstanceIdentity() async {
        let a = FlowCryptoActor.shared
        let b = FlowCryptoActor.shared
        #expect(a === b)
    }
}

// MARK: - NIOTransport / FlowTransport

@Suite("NIOTransport — delegates to FlowHTTPAPI shape", .serialized)
struct NIOTransportTests {
    @Test("NIOTransport init succeeds for testnet")
    func initTestnet() {
        let transport = NIOTransport(chainID: .testnet)
        _ = transport
    }

    @Test("NIOTransport init succeeds for mainnet")
    func initMainnet() {
        let transport = NIOTransport(chainID: .mainnet)
        _ = transport
    }
}

// MARK: - Helpers

private func makeDummyTransaction() throws -> Flow.Transaction {
    Flow.Transaction(
        script: Flow.Script(text: "access(all) fun main() {}"),
        arguments: [],
        referenceBlockId: testBlockID,
        gasLimit: BigUInt(100),
        proposalKey: Flow.TransactionProposalKey(
            address: testAddress,
            keyIndex: 0,
            sequenceNumber: 1
        ),
        payer: testAddress,
        authorizers: [testAddress]
    )
}
