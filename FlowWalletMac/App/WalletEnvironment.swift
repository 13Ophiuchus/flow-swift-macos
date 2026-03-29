//
//  WalletEnvironment.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


// Sources/FlowWalletMac/App/WalletEnvironment.swift

import Foundation
import SwiftData
import Flow

@MainActor
final class WalletEnvironment: ObservableObject {

    @Published var settings: WalletSettings
    @Published var accounts: [WalletAccount]
    @Published var selectedAccount: WalletAccount?
    @Published var connectionStatus: String = "Disconnected"
    @Published var lastError: String?

    let modelContext: ModelContext
    private let signer: SecureEnclaveFlowSigner
    private let parallelClient: FlowParallelClient

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.signer = SecureEnclaveFlowSigner()
        self.parallelClient = FlowParallelClient()

        let settingsFetch = FetchDescriptor<WalletSettings>()
        if let existing = try? modelContext.fetch(settingsFetch).first {
            self.settings = existing
        } else {
            let new = WalletSettings()
            modelContext.insert(new)
            self.settings = new
        }

        let accountsFetch = FetchDescriptor<WalletAccount>()
        self.accounts = (try? modelContext.fetch(accountsFetch)) ?? []

        self.selectedAccount = accounts.first(where: { $0.isDefault }) ?? accounts.first
    }

    func addAccount(name: String, addressHex: String, isDefault: Bool) {
        let account = WalletAccount(
            name: name,
            addressHex: addressHex,
            isDefault: isDefault
        )
        if isDefault {
            for acc in accounts {
                acc.isDefault = false
            }
        }
        modelContext.insert(account)
        accounts.append(account)
        selectedAccount = account
        try? modelContext.save()
    }

    func setMode(_ mode: WalletMode) {
        settings.mode = mode
        try? modelContext.save()
    }

    func refreshAccountState() async {
        guard let addr = selectedAccount?.address else { return }

        do {
            let data = try await parallelClient.loadAccounts([addr], maxConcurrent: 1)
            if let info = data[addr] {
                connectionStatus = "Balance: \(info["balance"] ?? "-")"
            } else {
                connectionStatus = "No data"
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
		// inside WalletEnvironment

	func signAndSend(transaction: Flow.Transaction) async throws -> Flow.ID {
		switch settings.mode {
			case .selfCustody:
				let signed = try await signer.sign(transaction: transaction)
				return try await Flow.shared.sendTransaction(signedTransaction: signed)

			case .custodial:
					// Call Vapor API /tx/submit with unsigned tx payload
				let base = settings.apiBaseURL
				guard let url = URL(string: "\(base)/api/v1/tx/submit") else {
					throw URLError(.badURL)
				}
				var request = URLRequest(url: url)
				request.httpMethod = "POST"
				request.setValue("application/json", forHTTPHeaderField: "Content-Type")

				let body = try JSONEncoder().encode(transaction)
				let (data, response) = try await URLSession.shared.upload(for: request, from: body)
				guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
					throw NSError(domain: "FlowWalletMac", code: 1, userInfo: [NSLocalizedDescriptionKey: "Server error"])
				}
				let result = try JSONDecoder().decode(TxSubmitResponse.self, from: data)
				return Flow.ID(hex: result.id)
		}
	}

	struct TxSubmitResponse: Decodable {
		let id: String
	}

}
