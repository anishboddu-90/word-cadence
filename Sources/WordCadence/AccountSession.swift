import AppKit
import CadenceCore
import Foundation

@MainActor
final class AccountSession: ObservableObject {
    @Published private(set) var records = ChatGPTAccounts()
    @Published private(set) var models: [ChatGPTModel] = []
    @Published private(set) var activity: String?
    @Published private(set) var message: String?
    @Published var modelID = ""

    private let oauth = ChatGPTOAuth()
    private let transcriber = PhotoTranscriber()
    private var operation: Task<Void, Never>?
    private var loaded = false

    var selected: ChatGPTAccount? { records.accounts.first { $0.id == records.selectedID } }
    var connected: Bool { selected?.credentials != nil }
    var canTranscribe: Bool { connected && !modelID.isEmpty && activity == nil }

    func load() {
        guard !loaded else { return }
        do {
            records = try AccountKeychain.load()
            loaded = true
            if connected { refreshModels() }
        } catch {
            message = error.localizedDescription
        }
    }

    func connect(_ account: ChatGPTAccount? = nil) {
        perform("Complete sign-in in your browser…") {
            self.load()
            guard self.loaded else { throw AppFailure.setup("Unlock macOS Keychain and try again.") }
            let connected = try await self.oauth.signIn(as: account)
            try Task.checkCancellation()
            try self.upsert(connected, select: true)
            self.models = []
            self.modelID = ""
            try await self.fetchModels()
        }
    }

    func select(_ id: String) {
        guard activity == nil, id != records.selectedID else { return }
        do {
            var updated = records
            updated.selectedID = id
            try persist(updated)
            models = []
            modelID = ""
            message = nil
            if connected { refreshModels() }
        } catch {
            message = error.localizedDescription
        }
    }

    func signOut() {
        guard var account = selected, account.credentials != nil else { return }
        perform("Signing out…") {
            let revoked = await self.oauth.revoke(account)
            account.credentials = nil
            // Stop using this session even if Keychain rejects an update.
            if let index = self.records.accounts.firstIndex(where: { $0.id == account.id }) {
                self.records.accounts[index] = account
            }
            self.models = []
            self.modelID = ""
            try AccountKeychain.save(self.records)
            if !revoked {
                self.message = "Signed out on this Mac. Remote revocation could not be confirmed. You can disconnect Word Cadence in ChatGPT settings."
            }
        }
    }

    func refreshModels() {
        perform("Loading ChatGPT models…") { try await self.fetchModels() }
    }

    func cancel() { operation?.cancel() }

    func transcribe(_ photos: [SourcePhoto], guidance: String) async throws -> CadenceCore.PageProposal {
        let model = modelID
        let token = try await accessToken()
        try Task.checkCancellation()
        return try await transcriber.transcribe(photos, model: model, token: token, guidance: guidance)
    }

    private func fetchModels() async throws {
        let catalog = try await transcriber.models(token: accessToken())
        models = catalog
        if !catalog.contains(where: { $0.slug == modelID }) {
            modelID = catalog.first?.slug ?? ""
        }
    }

    private func accessToken() async throws -> String {
        guard var account = selected, let credentials = account.credentials else {
            throw AppFailure.setup("Connect your ChatGPT account first.")
        }
        if credentials.expiresAt > Date().addingTimeInterval(45) {
            return credentials.accessToken
        }
        let fresh = try await oauth.refresh(account)
        account.credentials = fresh
        // Save a rotating refresh token before honoring a later cancellation.
        try upsert(account, select: false)
        return fresh.accessToken
    }

    private func perform(_ label: String, action: @escaping @MainActor () async throws -> Void) {
        guard operation == nil else { return }
        activity = label
        message = nil
        operation = Task {
            defer {
                self.activity = nil
                self.operation = nil
            }
            do {
                try await action()
            } catch {
                if !Task.isCancelled { self.message = error.localizedDescription }
            }
        }
    }

    private func upsert(_ account: ChatGPTAccount, select: Bool) throws {
        var updated = records
        if let index = updated.accounts.firstIndex(where: { $0.id == account.id }) {
            updated.accounts[index] = account
        } else {
            updated.accounts.append(account)
        }
        if select { updated.selectedID = account.id }
        try persist(updated)
    }

    private func persist(_ proposed: ChatGPTAccounts) throws {
        try AccountKeychain.save(proposed)
        records = proposed
    }
}
