import CadenceCore

enum PageChecks {
    static func run() {
        let proposal = PageProposal(pages: [
            PageDraft(id: 3, text: "Start.\nShared line"),
            PageDraft(id: 1, text: "Shared line\nand then"),
            PageDraft(id: 2, text: "the end.", join: .space)
        ])
        check((try? proposal.validate(ids: [1, 2, 3])) != nil)
        check((try? proposal.validate(ids: [1, 3, 3])) == nil)
        var revised = proposal
        revised.pages[1].overlap = "Shared line"
        checkEqual(try? revised.assembled(), "Start.\nShared line\nand then the end.")
        revised.pages[1].overlap = "shared line"
        check((try? revised.assembled()) == nil)
        let empty = PageProposal(pages: [PageDraft(id: 1, text: "\n ")])
        check((try? empty.assembled()) == nil)
    }
}
