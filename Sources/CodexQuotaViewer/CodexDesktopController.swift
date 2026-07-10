import AppKit
import Foundation

enum CodexDesktopControlError: LocalizedError {
    case appMissing
    case openFailed
    case closeTimedOut

    var errorDescription: String? {
        switch self {
        case .appMissing:
            return AppLocalization.localized(
                en: "ChatGPT.app or Codex.app was not found in /Applications.",
                zh: "在 /Applications 中找不到 ChatGPT.app 或 Codex.app。"
            )
        case .openFailed:
            return AppLocalization.localized(en: "ChatGPT or Codex could not be reopened.", zh: "ChatGPT 或 Codex 无法重新打开。")
        case .closeTimedOut:
            return AppLocalization.localized(
                en: "ChatGPT or Codex did not close in time. Safe switch was aborted.",
                zh: "ChatGPT 或 Codex 未能及时关闭，安全切换已中止。"
            )
        }
    }
}

@MainActor
protocol CodexDesktopControlling: AnyObject {
    var isRunning: Bool { get }
    func closeIfRunning() async throws -> Bool
    func reopenIfNeeded(previouslyRunning: Bool) async throws
}

@MainActor
final class CodexDesktopController: CodexDesktopControlling {
    private let bundleIdentifier = "com.openai.codex"
    private let fallbackAppURLs = [
        URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
        URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true),
    ]
    private var lastClosedBundleURL: URL?

    var isRunning: Bool {
        !runningApplications.isEmpty
    }

    func closeIfRunning() async throws -> Bool {
        let apps = runningApplications
        guard !apps.isEmpty else {
            lastClosedBundleURL = nil
            return false
        }

        lastClosedBundleURL = apps.compactMap(\.bundleURL).first

        for app in apps {
            _ = app.terminate()
        }

        try await waitForExit(timeout: 8)
        if !isRunning {
            return true
        }

        for app in runningApplications {
            _ = app.forceTerminate()
        }

        try await waitForExit(timeout: 4)
        if !isRunning {
            return true
        }

        throw CodexDesktopControlError.closeTimedOut
    }

    private func waitForExit(timeout: TimeInterval) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isRunning {
                return
            }
            try? await Task.sleep(nanoseconds: 250_000_000)
        }
    }

    func reopenIfNeeded(previouslyRunning: Bool) async throws {
        guard previouslyRunning else {
            return
        }

        guard !isRunning else {
            return
        }

        guard let appURL = codexDesktopAppURL(
            lastClosedBundleURL: lastClosedBundleURL,
            fallbackAppURLs: fallbackAppURLs,
            fileExists: FileManager.default.fileExists(atPath:)
        ) else {
            throw CodexDesktopControlError.appMissing
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard app != nil else {
                    continuation.resume(throwing: CodexDesktopControlError.openFailed)
                    return
                }

                continuation.resume()
            }
        }
    }

    private var runningApplications: [NSRunningApplication] {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { !$0.isTerminated }
    }
}

func codexDesktopAppURL(
    lastClosedBundleURL: URL?,
    fallbackAppURLs: [URL],
    fileExists: (String) -> Bool
) -> URL? {
    for appURL in uniqueAppURLs([lastClosedBundleURL].compactMap { $0 } + fallbackAppURLs) {
        if fileExists(appURL.path) {
            return appURL
        }
    }

    return nil
}

private func uniqueAppURLs(_ urls: [URL]) -> [URL] {
    var seen = Set<String>()
    var result: [URL] = []

    for url in urls {
        let key = url.standardizedFileURL.path
        guard seen.insert(key).inserted else {
            continue
        }
        result.append(url)
    }

    return result
}
