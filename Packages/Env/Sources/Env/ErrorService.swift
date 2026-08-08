import Foundation
import SwiftUI
import Observation

@MainActor
@Observable
public class ErrorService {
    public static let shared = ErrorService()

    public var isErrorDisplayed: Bool = false
    public var currentErrorTitle: String = "Error"
    public var currentErrorMessage: String = ""

    private var logFileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("IceCubes_Errors.log")
    }

    private init() {}

    public func handle(_ error: Error, message: String, showPopup: Bool = UserPreferences.shared.showErrorPopups, log: Bool = UserPreferences.shared.logErrors) {
        handle(title: message, message: error.localizedDescription, showPopup: showPopup, log: log)
    }

    public func handle(title: String, message: String, showPopup: Bool = UserPreferences.shared.showErrorPopups, log: Bool = UserPreferences.shared.logErrors) {
        if log {
            let logMessage = "[\(Date().description)] \(title): \(message)\n"
            if let data = logMessage.data(using: .utf8) {
                if FileManager.default.fileExists(atPath: logFileURL.path) {
                    if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
                        fileHandle.seekToEndOfFile()
                        fileHandle.write(data)
                        fileHandle.closeFile()
                    }
                } else {
                    try? data.write(to: logFileURL)
                }
            }
        }
        
        if showPopup {
            self.currentErrorTitle = title
            self.currentErrorMessage = message
            self.isErrorDisplayed = true
        }
    }
    
    public func readLogs() -> String? {
        return try? String(contentsOf: logFileURL, encoding: .utf8)
    }
    
    public func clearLogs() {
        try? FileManager.default.removeItem(at: logFileURL)
    }
}
