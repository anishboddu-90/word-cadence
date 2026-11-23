import CadenceCore
import SwiftUI

struct PhotoReviewView: View {
    @ObservedObject var review: PhotoReview
    var confirm: () -> Void
    var revise: () -> Void
    var close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Confirm the reading order")
                .font(.title2.weight(.semibold))
            if !review.proposal.questions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(review.proposal.questions.enumerated()), id: \.offset) { _, question in
                            Label(question, systemImage: "questionmark.circle")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                }
                .frame(maxHeight: 86)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack(alignment: .top, spacing: 16) {
                orderList.frame(width: 185)
                Divider()
                pageDetails
            }
            .frame(maxHeight: .infinity)

            HStack {
                TextField("Answer a question or describe the order", text: $review.clarification)
                Button(review.busy ? "Revising…" : "Ask ChatGPT to revise", action: revise)
                    .disabled(review.busy || review.clarification.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let error = review.error {
                Text(error).foregroundStyle(Color.red).font(.callout)
            }

            HStack {
                Button("Close", action: close)
                Spacer()
                if review.busy { ProgressView().controlSize(.small) }
                Button("Confirm & Use Transcript", action: confirm)
                    .buttonStyle(.borderedProminent)
                    .disabled(review.busy)
            }
        }
        .padding(20)
        .frame(minWidth: 730, minHeight: 520)
    }

    private var orderList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Reading order").font(.headline)
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(review.proposal.pages.enumerated()), id: \.element.id) { index, page in
                        Button {
                            review.selectedID = page.id
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(index + 1)").monospacedDigit().foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Photo \(page.id)").fontWeight(.semibold)
                                    Text(photo(id: page.id)?.name ?? "").font(.caption).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(7)
                            .background(review.selectedID == page.id ? Color.accentColor.opacity(0.18) : .clear,
                                        in: RoundedRectangle(cornerRadius: 7))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            HStack {
                Button { review.moveSelection(-1) } label: { Image(systemName: "arrow.up") }
                    .help("Move selected photo earlier")
                    .accessibilityLabel("Move photo earlier")
                    .disabled(review.selectionIndex.map { $0 == 0 } ?? true)
                Button { review.moveSelection(1) } label: { Image(systemName: "arrow.down") }
                    .help("Move selected photo later")
                    .accessibilityLabel("Move photo later")
                    .disabled(review.selectionIndex.map { $0 == review.proposal.pages.count - 1 } ?? true)
            }
        }
        .disabled(review.busy)
    }

    @ViewBuilder
    private var pageDetails: some View {
        if let index = review.selectionIndex {
            let page = $review.proposal.pages[index]
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    if let jpeg = photo(id: page.wrappedValue.id)?.jpeg, let preview = NSImage(data: jpeg) {
                        ScrollView([.horizontal, .vertical]) {
                            Image(nsImage: preview)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 250)
                                .accessibilityLabel("Source photo \(page.wrappedValue.id)")
                        }
                        .frame(minWidth: 180, idealWidth: 225, maxWidth: 250)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Transcription").font(.headline)
                        TextEditor(text: page.text)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityLabel("Photo transcript")
                            .padding(5)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                        if !page.wrappedValue.notes.isEmpty {
                            Text(page.wrappedValue.notes.joined(separator: " "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                        }
                    }
                }

                if index > 0 {
                    Picker("Join to previous photo", selection: page.join) {
                        Text("New paragraph").tag(PageDraft.Join.paragraph)
                        Text("New line").tag(PageDraft.Join.line)
                        Text("Space").tag(PageDraft.Join.space)
                        Text("No separator").tag(PageDraft.Join.continuous)
                    }
                    .disabled(!page.wrappedValue.overlap.isEmpty)
                    if !page.wrappedValue.overlap.isEmpty {
                        HStack {
                            Text("Shared text to include once").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Clear overlap") { page.overlap.wrappedValue = "" }
                        }
                        TextEditor(text: page.overlap)
                            .frame(height: 42)
                            .accessibilityLabel("Text shared with the previous photo")
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
                    }
                }
            }
            .id(page.wrappedValue.id)
            .disabled(review.busy)
        }
    }

    private func photo(id: Int) -> SourcePhoto? { review.photos.first { $0.id == id } }
}
