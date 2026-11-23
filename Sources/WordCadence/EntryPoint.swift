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
        if CommandLine.arguments.dropFirst() == ["--verify-photos"] {
            Task {
                do {
                    try await PhotoIntegrationCheck.run()
                    exit(0)
                } catch {
                    FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                    exit(1)
                }
            }
            RunLoop.main.run()
            return
        }
        #endif
        WordCadenceApp.main()
    }
}
