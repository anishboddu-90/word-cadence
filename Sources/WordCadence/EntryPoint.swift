import Foundation
import SwiftUI

@main
@MainActor
enum EntryPoint {
    static func main() {
        #if DEBUG
        if CommandLine.arguments.dropFirst() == ["--verify-word"] {
            runCheck(WordIntegrationCheck.run)
            return
        }
        if CommandLine.arguments.dropFirst() == ["--verify-photos"] {
            runCheck(PhotoIntegrationCheck.run)
            return
        }
        #endif
        WordCadenceApp.main()
    }

    #if DEBUG
    private static func runCheck(_ check: @escaping @MainActor () async throws -> Void) {
        Task {
            do {
                try await check()
                exit(0)
            } catch {
                FileHandle.standardError.write(Data((error.localizedDescription + "\n").utf8))
                exit(1)
            }
        }
        RunLoop.main.run()
    }
    #endif
}
