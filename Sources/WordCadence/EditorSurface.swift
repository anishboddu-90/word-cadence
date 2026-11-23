import SwiftUI

struct EditorSurface: View {
    @Binding var text: String
    let placeholder: String

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 15))
            .scrollContentBackground(.hidden)
            .padding(10)
            .frame(minHeight: 140, maxHeight: .infinity)
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder).foregroundStyle(.secondary)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 11)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.quaternary))
            .accessibilityLabel("Text to write to Microsoft Word")
    }
}
