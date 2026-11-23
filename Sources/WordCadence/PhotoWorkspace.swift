import AppKit
import CadenceCore

@MainActor
final class PhotoWorkspace: ObservableObject {
    @Published private(set) var photos: [SourcePhoto] = []
    @Published private(set) var review: PhotoReview?
    @Published private(set) var status: String?
    @Published private(set) var busy = false
    @Published var transcript = ""

    private var nextID = 1
    private var panel: ReviewPanel?
    private var operation: Task<Void, Never>?

    func choosePhotos() {
        guard !busy, photos.count < SourcePhoto.maximumCount else { return }
        let picker = NSOpenPanel()
        picker.prompt = "Add Photos"
        picker.allowedContentTypes = [.image]
        picker.allowsMultipleSelection = true
        picker.canChooseDirectories = false
        picker.begin { answer in
            if answer == .OK { self.importPhotos(picker.urls) }
        }
    }

    func remove(_ photo: SourcePhoto) {
        guard !busy else { return }
        if let index = photos.firstIndex(where: { $0.id == photo.id }) {
            photos.remove(at: index)
            discardProposal()
        }
    }

    func requestReview(account: AccountSession) {
        guard !busy, account.canTranscribe, !photos.isEmpty else { return }
        discardProposal()
        transcribe(account: account, existing: nil)
    }

    func showReview(account: AccountSession) {
        guard let review else { return }
        if panel == nil {
            panel = ReviewPanel {
                PhotoReviewView(review: review) { [weak self] in
                    self?.confirm(review)
                } revise: { [weak self, weak account] in
                    guard let self, let account, account.canTranscribe else { return }
                    self.transcribe(account: account, existing: review)
                } close: { [weak self] in
                    self?.panel?.orderOut(nil)
                }
            }
        }
        panel?.present()
    }

    func cancel() { operation?.cancel() }

    private func importPhotos(_ urls: [URL]) {
        guard !busy else { return }
        guard urls.count + photos.count <= SourcePhoto.maximumCount else {
            status = "Choose up to \(SourcePhoto.maximumCount) photos per batch."
            return
        }
        let firstID = nextID
        busy = true
        status = "Preparing photos…"
        operation = Task {
            defer { finishOperation() }
            do {
                let loaded = try await Task.detached(priority: .userInitiated) {
                    try SourcePhoto.load(urls, startingAt: firstID)
                }.value
                try Task.checkCancellation()
                photos += loaded
                nextID += loaded.count
                discardProposal()
            } catch {
                status = Task.isCancelled ? "Import canceled." : error.localizedDescription
            }
        }
    }

    private func transcribe(account: AccountSession, existing: PhotoReview?) {
        guard !busy else { return }
        let batch = photos
        let guidance = existing?.clarification ?? ""
        busy = true
        status = "Waiting for ChatGPT…"
        existing?.busy = true
        existing?.error = nil
        operation = Task {
            defer {
                existing?.busy = false
                finishOperation()
            }
            do {
                let proposed = try await account.transcribe(batch, guidance: guidance)
                try Task.checkCancellation()
                if let existing {
                    existing.update(from: proposed)
                } else {
                    review = PhotoReview(photos: batch, proposal: proposed)
                }
                status = "Review the proposed order and transcript."
                showReview(account: account)
            } catch {
                let message = Task.isCancelled ? "Transcription canceled." : error.localizedDescription
                status = message
                existing?.error = message
            }
        }
    }

    private func confirm(_ review: PhotoReview) {
        guard self.review === review, !busy else { return }
        do {
            transcript = try review.proposal.assembled()
            status = "Transcript confirmed. Review or edit it before writing."
            panel?.orderOut(nil)
        } catch {
            review.error = error.localizedDescription
        }
    }

    private func discardProposal() {
        panel?.orderOut(nil)
        panel = nil
        review = nil
        status = nil
    }

    private func finishOperation() {
        busy = false
        operation = nil
    }
}
