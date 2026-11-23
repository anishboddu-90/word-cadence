import CadenceCore
import SwiftUI

private enum TextSource: String, CaseIterable {
    case manual = "Manual Text"
    case photos = "Photos"
}

struct WorkspaceView: View {
    let word: WordClient
    @ObservedObject var run: WritingRun
    @StateObject private var photos = PhotoWorkspace()
    @StateObject private var account = AccountSession()

    @AppStorage("targetWPM") private var wpm = 55
    @AppStorage("correctionPercent") private var corrections = 2
    @State private var source = TextSource.manual
    @State private var manual = ""
    @State private var documents: [WordDocument] = []
    @State private var target: WordDocument?
    @State private var wordMessage: String?
    @State private var checkingWord = false

    private var writing: Bool { run.phase != .idle }
    private var text: String { source == .manual ? manual : photos.transcript }
    private var pace: Pace { Pace(wordsPerMinute: wpm, correctionPercent: corrections) }
    private var characterCount: Int { text.count }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: "text.cursor")
                    .font(.system(size: 25, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 46, height: 46)
                    .background(Color.accentColor.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                Text("Word Cadence").font(.system(size: 25, weight: .semibold))
                Spacer()
                Picker("Text source", selection: $source) {
                    ForEach(TextSource.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Text source")
                .frame(width: 220)
                .disabled(writing)
            }
            .padding(20)
            Divider()

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    if source == .manual {
                        Text("Text to write").font(.headline)
                        EditorSurface(text: $manual, placeholder: "Paste or enter your text.")
                            .disabled(writing)
                    } else {
                        PhotoSourceView(account: account, workspace: photos, writing: writing)
                    }
                    Text("\(characterCount.formatted()) characters")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack(alignment: .leading, spacing: 18) {
                    destination
                    Divider()
                    paceControls
                    Spacer()
                }
                .frame(width: 236)
                .padding(15)
                .frame(maxHeight: .infinity)
                .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 12))
                .disabled(writing)
            }
            .padding(20)

            Divider()
            footer.padding(.horizontal, 20).padding(.vertical, 13)
        }
        .frame(minWidth: 820, minHeight: 550)
        .task { await reloadDocuments(prompt: false) }
        .onChange(of: source) { _, selection in
            if selection == .photos { account.load() }
        }
    }

    private var destination: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Word destination", systemImage: "doc.text").font(.headline)
                Spacer()
                Button {
                    Task { await reloadDocuments(prompt: true) }
                } label: {
                    if checkingWord {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                    .disabled(checkingWord)
                    .help("Refresh open Word documents")
                    .accessibilityLabel("Refresh open Word documents")
            }
            Picker("Open document", selection: $target) {
                Text("Select a document").tag(nil as WordDocument?)
                ForEach(documents) { document in
                    Text(documents.filter { $0.name == document.name }.count > 1 ? document.path : document.name)
                        .tag(Optional(document))
                }
            }
            .labelsHidden()
            .accessibilityLabel("Open Word document")
            .frame(maxWidth: .infinity)
            Text(wordMessage ?? "Brings the selected Word document forward and appends at the end.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var paceControls: some View {
        VStack(alignment: .leading, spacing: 11) {
            Label("Pace", systemImage: "speedometer").font(.headline)
            HStack {
                TextField("Words per minute", value: $wpm, format: .number)
                    .labelsHidden()
                    .accessibilityLabel("Words per minute")
                    .frame(width: 52)
                Stepper("WPM", value: $wpm, in: Pace.speedRange)
                Spacer()
            }
            Slider(value: Binding(get: { Double(pace.wordsPerMinute) }, set: { wpm = Int($0) }),
                   in: Double(Pace.speedRange.lowerBound)...Double(Pace.speedRange.upperBound), step: 1)
                .accessibilityLabel("Words per minute")
            Stepper(value: $corrections, in: Pace.correctionRange) {
                Text("Corrected typos  \(pace.correctionPercent)%")
            }
            if characterCount > 0 {
                let time = Duration.seconds(pace.targetDuration(for: characterCount))
                Text("About \(time.formatted(.units(allowed: [.hours, .minutes, .seconds], width: .abbreviated, maximumUnitCount: 2)))")
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(run.message)
                    .lineLimit(3)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if writing {
                    ProgressView(value: Double(run.completed), total: Double(max(1, run.total)))
                        .accessibilityLabel("Writing progress")
                }
            }
            Spacer()
            if writing {
                Button(run.phase == .paused ? "Resume" : "Pause", action: run.togglePause)
                    .disabled(run.phase == .stopping)
                Button("Stop", action: run.stop)
                    .disabled(run.phase == .stopping)
            } else {
                Button("Write to Word") {
                    guard let target else { return }
                    wpm = pace.wordsPerMinute
                    corrections = pace.correctionPercent
                    run.start(text: text, pace: pace, document: target)
                }
                .buttonStyle(.borderedProminent)
                .disabled(text.isEmpty || target == nil || (source == .photos && photos.busy))
            }
        }
    }

    private func reloadDocuments(prompt: Bool) async {
        guard !checkingWord else { return }
        checkingWord = true
        defer { checkingWord = false }
        if prompt { wordMessage = "Checking Word access. Respond to the macOS prompt if it appears." }
        do {
            try await word.checkPermission(prompt: prompt)
            try Task.checkCancellation()
            let found = try word.documents()
            documents = Array(Set(found)).sorted {
                $0.name == $1.name ? $0.path < $1.path : $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            if let target, !documents.contains(target) { self.target = nil }
            wordMessage = documents.isEmpty ? "Open a document in Microsoft Word, then refresh." : nil
        } catch {
            documents = []
            target = nil
            wordMessage = error.localizedDescription
        }
    }
}
