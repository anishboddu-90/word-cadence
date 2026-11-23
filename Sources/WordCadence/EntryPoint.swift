import Foundation
import SwiftUI

@main
@MainActor
enum EntryPoint {
    static func main() {
        #if DEBUG
        if CommandLine.arguments.dropFirst() == ["--verify-word"] {
            do {
                try WordIntegrationCheck.run()
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
            return
        }
        #endif
        WordCadenceApp.main()
    }
}
