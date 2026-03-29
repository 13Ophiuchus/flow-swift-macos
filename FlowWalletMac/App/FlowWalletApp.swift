//
//  FlowWalletApp.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


// Sources/FlowWalletMac/App/FlowWalletApp.swift

import SwiftUI
import SwiftData

@main
struct FlowWalletApp: App {

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WalletAccount.self,
            WalletSettings.self
        ])

        return try! ModelContainer(
            for: schema,
            configurations: [
                ModelConfiguration(isStoredInMemoryOnly: false)
            ]
        )
    }()

    var body: some Scene {
        WindowGroup {
            WalletRootView()
                .modelContainer(sharedModelContainer)
        }
    }
}

// Sources/FlowWalletMac/App/WalletRootView.swift

import SwiftUI
import SwiftData

struct WalletRootView: View {

    @Environment(\.modelContext) private var context
    @StateObject private var envHolder = EnvHolder()

    var body: some View {
        Group {
            if let env = envHolder.env {
                WalletMainView()
                    .environmentObject(env)
            } else {
                ProgressView("Initializing Wallet...")
                    .task {
                        await envHolder.load(context: context)
                    }
            }
        }
    }
}

@MainActor
final class EnvHolder: ObservableObject {
    @Published var env: WalletEnvironment?

    func load(context: ModelContext) async {
        self.env = WalletEnvironment(modelContext: context)
    }
}

// Sources/FlowWalletMac/App/WalletMainView.swift

import SwiftUI

struct WalletMainView: View {

    @EnvironmentObject var env: WalletEnvironment
    @State private var newName: String = ""
    @State private var newAddressHex: String = ""
    @State private var isDefault: Bool = false

    var body: some View {
        NavigationView {
            List(selection: Binding(
                get: { env.selectedAccount?.id },
                set: { id in
                    env.selectedAccount = env.accounts.first(where: { $0.id == id })
                }
            )) {
                Section("Accounts") {
                    ForEach(env.accounts, id: \.id) { acc in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(acc.name)
                                Text(acc.addressHex)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if acc.isDefault {
                                Text("Default")
                                    .font(.caption2)
                                    .padding(4)
                                    .background(Color.green.opacity(0.2))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }

                Section("Add Account") {
                    TextField("Name", text: $newName)
                    TextField("0x...", text: $newAddressHex)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Set as default", isOn: $isDefault)
                    Button("Add") {
                        env.addAccount(
                            name: newName,
                            addressHex: newAddressHex,
                            isDefault: isDefault
                        )
                        newName = ""
                        newAddressHex = ""
                        isDefault = false
                    }
                    .disabled(newAddressHex.isEmpty)
                }
            }
            .frame(minWidth: 300)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Picker("Mode", selection: Binding(
                        get: { env.settings.mode },
                        set: { env.setMode($0) }
                    )) {
                        Text("Self‑Custody").tag(WalletMode.selfCustody)
                        Text("Custodial").tag(WalletMode.custodial)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                if let acc = env.selectedAccount {
                    Text("Selected: \(acc.name)")
                        .font(.headline)
                    Text("Address: \(acc.addressHex)")
                        .font(.subheadline)
                } else {
                    Text("No account selected")
                }

                Text("Connection: \(env.connectionStatus)")
                    .foregroundStyle(.secondary)

                if let err = env.lastError {
                    Text("Error: \(err)")
                        .foregroundColor(.red)
                }

                HStack {
                    Button("Refresh Account State") {
                        Task { await env.refreshAccountState() }
                    }

                    Button("Open Settings in Vapor App") {
                        if let url = URL(string: env.settings.apiBaseURL) {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }

                Spacer()
            }
            .padding()
        }
    }
}
