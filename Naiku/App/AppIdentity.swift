import Foundation

enum AppIdentity {
    static let displayName = "Naiku"
}

enum AppRuntime {
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
