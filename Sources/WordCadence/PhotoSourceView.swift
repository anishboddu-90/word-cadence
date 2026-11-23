import SwiftUI

struct PhotoSourceView: View {
    @ObservedObject var account: AccountSession
    @ObservedObject var workspace: PhotoWorkspace
    let writing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            connection
            if let activity = account.activity {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(activity).font(.callout)
                    Button("Cancel", action: account.cancel).controlSize(.small)
                }
            }
            if let message = account.message {
                Text(message).font(.callout).foregroundStyle(.secondary)
            }

            HStack {
                Button("Add Photos…", action: workspace.choosePhotos)
                    .disabled(workspace.busy || workspace.photos.count >= SourcePhoto.maximumCount || writing)
                Button("Transcribe & Order") { workspace.requestReview(account: account) }
                    .disabled(workspace.busy || workspace.photos.isEmpty || !account.canTranscribe || writing)
                if workspace.review != nil {
                    Button("Open Review") { workspace.showReview(account: account) }.disabled(writing)
                }
                Spacer()
                if workspace.busy {
                    ProgressView().controlSize(.small)
                    Button("Cancel", action: workspace.cancel).controlSize(.small)
                }
            }
            if !workspace.photos.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 6) {
                        ForEach(workspace.photos) { photo in
                            HStack(spacing: 5) {
                                Text("\(photo.id). \(photo.name)").lineLimit(1)
                                Button { workspace.remove(photo) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove \(photo.name)")
                                .disabled(workspace.busy || writing)
                            }
                            .font(.caption)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                            .frame(maxWidth: 215)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
            if let status = workspace.status {
                Text(status).font(.callout).foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            EditorSurface(text: $workspace.transcript, placeholder: "Confirmed photo text appears here.")
                .disabled(writing || workspace.busy)
        }
    }

    private var connection: some View {
        HStack {
            if let selected = account.selected {
                Menu {
                    ForEach(account.records.accounts) { choice in
                        Button(choice.label) { account.select(choice.id) }
                    }
                    Divider()
                    Button("Add ChatGPT account…") { account.connect() }
                    Button("Reconnect this account") { account.connect(selected) }
                    if account.connected {
                        Button("Reload models", action: account.refreshModels)
                        Button("Sign out", action: account.signOut)
                    }
                    Link("Manage ChatGPT usage", destination: URL(string: "https://chatgpt.com/settings/usage")!)
                } label: {
                    Label(selected.label, systemImage: account.connected ? "person.crop.circle.badge.checkmark" : "person.crop.circle")
                        .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)
            } else {
                Button("Continue with ChatGPT") { account.connect() }
            }

            if !account.models.isEmpty {
                Picker("Model", selection: $account.modelID) {
                    ForEach(account.models) { model in
                        Text(model.displayName).tag(model.slug)
                    }
                }
                .labelsHidden()
                .accessibilityLabel("ChatGPT model")
                .frame(maxWidth: 184)
            }
        }
        .disabled(workspace.busy || writing || account.activity != nil)
    }
}
