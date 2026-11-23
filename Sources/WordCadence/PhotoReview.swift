import CadenceCore
import Foundation

@MainActor
final class PhotoReview: ObservableObject {
    let photos: [SourcePhoto]
    @Published var proposal: PageProposal
    @Published var selectedID: Int
    @Published var clarification = ""
    @Published var busy = false
    @Published var error: String?

    private var originalText: [Int: String]

    init(photos: [SourcePhoto], proposal: PageProposal) {
        self.photos = photos
        self.proposal = proposal
        self.selectedID = proposal.pages.first?.id ?? 0
        self.originalText = Dictionary(uniqueKeysWithValues: proposal.pages.map { ($0.id, $0.text) })
    }

    var selectionIndex: Int? { proposal.pages.firstIndex { $0.id == selectedID } }

    func moveSelection(_ offset: Int) {
        guard let current = selectionIndex, proposal.pages.indices.contains(current + offset) else { return }
        let oldPreviousIDs = previousIDs()
        let page = proposal.pages.remove(at: current)
        proposal.pages.insert(page, at: current + offset)
        let newPreviousIDs = previousIDs()
        for index in proposal.pages.indices {
            let id = proposal.pages[index].id
            if oldPreviousIDs[id] != newPreviousIDs[id] {
                proposal.pages[index].overlap = ""
                proposal.pages[index].join = .paragraph
            }
        }
        error = nil
    }

    func update(from revised: PageProposal) {
        let edited = Dictionary(uniqueKeysWithValues: proposal.pages.filter { originalText[$0.id] != $0.text }
            .map { ($0.id, $0.text) })
        originalText = Dictionary(uniqueKeysWithValues: revised.pages.map { ($0.id, $0.text) })
        proposal = revised
        for index in proposal.pages.indices {
            if let text = edited[proposal.pages[index].id] { proposal.pages[index].text = text }
        }
        clarification = ""
        error = nil
    }

    private func previousIDs() -> [Int: Int] {
        Dictionary(uniqueKeysWithValues: zip(proposal.pages.dropFirst(), proposal.pages).map { ($0.id, $1.id) })
    }
}
