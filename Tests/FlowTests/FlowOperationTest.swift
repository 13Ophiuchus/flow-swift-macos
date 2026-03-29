	//
	//  FlowOperationTests.swift
	//  FlowTests
	//
	//  Copyright 2022 Outblock Pty Ltd
	//
	//  Licensed under the Apache License, Version 2.0 (the "License");
	//  you may not use this file except in compliance with the License.
	//  You may obtain a copy of the License at
	//
	//    http://www.apache.org/licenses/LICENSE-2.0
	//
	//  Unless required by applicable law or agreed to in writing, software
	//  distributed under the License is distributed on an "AS IS" BASIS,
	//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	//  See the License for the specific language governing permissions and
	//  limitations under the License.
	//
	//  Migrated to Swift Testing by Nicholas Reich on 2026-03-19.
	//  Updated for Swift 6 compile safety on 2026-03-29.
	//

@testable import BigInt
import Combine
import CryptoKit
@testable import Flow
import Foundation
import Testing

	// To avoid unnecessary network calls, all examples remain disabled.
	// To enable, port them to the new Flow transaction-building APIs and
	// turn them into @Test methods.

@Suite
struct FlowOperationTests {

		// MARK: - Static fixtures

	let address = Flow.Address(hex: "0xe242ccfb4b8ea3e2")

	let publicKey = try! P256.KeyAgreement.PublicKey(
		rawRepresentation:
			"adbf18dae6671e6b6a92edf00c79166faba6babf6ec19bd83eabf690f386a9b13c8e48da67973b9cf369f56e92ec25ede5359539f687041d27d0143afd14bca9"
			.hexValue
	)

	let privateKey = try! P256.Signing.PrivateKey(
		rawRepresentation:
			"1eb79c40023143821983dc79b4e639789ea42452e904fda719f5677a1f144208"
			.hexValue
	)

	let privateKeyA = try! P256.Signing.PrivateKey(
		rawRepresentation:
			"c9c0f04adddf7674d265c395de300a65a777d3ec412bba5bfdfd12cffbbb78d9"
			.hexValue
	)

	let scriptName = "HelloWorld"

	let script = """
	pub contract HelloWorld {
	
		pub let greeting: String
	
		pub fun hello(): String {
			return self.greeting
		}
	
		init() {
			self.greeting = "Hello World!"
		}
	}
	"""

		// Keeping these as computed properties avoids mutation in init / async init issues.
	var cancellables: Set<AnyCancellable> { [] }

	var signers: [ECDSA_P256_Signer] {
		[
			ECDSA_P256_Signer(
				address: address,
				keyIndex: 0,
				privateKey: privateKey
			)
		]
	}

		// MARK: - Compile-safety smoke tests

	@Test("Signer fixtures build")
	func signerFixturesBuild() async throws {
		#expect(address.hex == "0xe242ccfb4b8ea3e2")
		#expect(signers.count == 1)
		#expect(scriptName == "HelloWorld")
		#expect(script.contains("pub contract HelloWorld"))
	}

	@Test("Secondary private key can derive public key")
	func secondaryPrivateKeyBuilds() async throws {
		let derived = privateKeyA.publicKey.rawRepresentation
		#expect(!derived.isEmpty)
	}

		// MARK: - Example operations (disabled)

	/*
	 // Legacy examples using old Flow convenience APIs. These no longer exist on
	 // the Flow type and must be rewritten using the modern transaction builder.

	 // Suggested modern setup:
	 //
	 // let access = FlowAccessActor(initialChainID: Flow.ChainID.testnet)
	 // await access.configure(chainID: Flow.ChainID.testnet)
	 //
	 // Build transactions explicitly using the current transaction builder APIs,
	 // then submit through FlowAccessActor / FlowAccessProtocol.

	 func exampleAddContractToAccount() async throws {
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleRemoveAccountKeyByIndex() async throws {
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleAddKeyToAccount() async throws {
	 let accountKey = Flow.AccountKey(
	 publicKey: Flow.PublicKey(hex: privateKeyA.publicKey.rawRepresentation.hexValue),
	 signAlgo: .ECDSA_P256,
	 hashAlgo: .SHA2_256,
	 weight: 1000
	 )

	 _ = accountKey
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleUpdateContractOfAccount() async throws {
	 let script2 = """
	 pub contract HelloWorld {

	 pub struct SomeStruct {
	 pub var x: Int
	 pub var y: Int

	 init(x: Int, y: Int) {
	 self.x = x
	 self.y = y
	 }
	 }

	 pub let greeting: String

	 init() {
	 self.greeting = "Hello World!"
	 }
	 }
	 """

	 _ = script2
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleCreateAccount() async throws {
	 let accountKey = Flow.AccountKey(
	 publicKey: Flow.PublicKey(
	 hex: privateKeyA.publicKey.rawRepresentation.hexValue
	 ),
	 signAlgo: .ECDSA_P256,
	 hashAlgo: .SHA2_256,
	 weight: 1000
	 )

	 _ = accountKey
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleRemoveContractFromAccount() async throws {
	 // Rewrite using modern transaction builder APIs.
	 }

	 func exampleVerifyUserSignature() async throws {
	 let message = "464c4f57..."
	 let signature =
	 "0a467f133a971a8e022da54f988c033c05639cddd3bd8a525e566b53ee8e55a112cab1d3f1c628d7d290ec4c00782d8333ba0d8b17ec76408950968db0073aa5"
	 .hexValue
	 .data

	 let txSignature = Flow.TransactionSignature(
	 address: Flow.Address(hex: "0xe242ccfb4b8ea3e2"),
	 keyIndex: 0,
	 signature: signature
	 )

	 _ = message
	 _ = txSignature
	 // Rewrite using modern signature verification APIs.
	 }
	 */
}
