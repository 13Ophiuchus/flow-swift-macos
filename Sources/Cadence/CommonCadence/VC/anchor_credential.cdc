// CommonCadence/VC/anchor_credential.cdc

transaction(credentialID: String, subjectDID: String) {
    prepare(signer: auth(Storage, Capabilities) &Account) {
        log("Anchoring credential")
        log(credentialID)
        log(subjectDID)
    }

    execute {
        log("Credential anchored (dev stub)")
    }
}
