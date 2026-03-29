//
//  WalletAccount.swift
//  Flow
//
//  Created by Nicholas Reich on 3/26/26.
//


// Sources/FlowWalletMac/Models/WalletModels.swift

import Foundation
import SwiftData
import Flow

@Model
public final class WalletAccount {
    @Attribute(.unique) public var id: UUID
    public var name: String
    public var addressHex: String
    public var createdAt: Date
    public var isDefault: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        addressHex: String,
        createdAt: Date = .now,
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.addressHex = addressHex
        self.createdAt = createdAt
        self.isDefault = isDefault
    }

    public var address: Flow.Address? {
        Flow.Address(hex: addressHex)
    }
}

public enum WalletMode: String, Codable, CaseIterable {
    case selfCustody   // Secure Enclave signing
    case custodial     // sign via FlowVaporApp
}

@Model
public final class WalletSettings {
    @Attribute(.unique) public var id: UUID
    public var modeRaw: String
    public var apiBaseURL: String   // FlowVaporApp base URL
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        mode: WalletMode = .selfCustody,
        apiBaseURL: String = "https://localhost:8080",
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.modeRaw = mode.rawValue
        self.apiBaseURL = apiBaseURL
        self.lastUpdated = lastUpdated
    }

    public var mode: WalletMode {
        get { WalletMode(rawValue: modeRaw) ?? .selfCustody }
        set {
            modeRaw = newValue.rawValue
            lastUpdated = .now
        }
    }
}
