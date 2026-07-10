import Foundation
import Testing

@testable import CodexQuotaViewer

@Test
func codexDesktopAppURLPrefersLastClosedBundleURLWhenItStillExists() {
    let lastClosed = URL(fileURLWithPath: "/Applications/ChatGPT Beta.app", isDirectory: true)
    let chatGPT = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
    let codex = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)

    let selected = codexDesktopAppURL(
        lastClosedBundleURL: lastClosed,
        fallbackAppURLs: [chatGPT, codex],
        fileExists: { $0 == lastClosed.path || $0 == chatGPT.path || $0 == codex.path }
    )

    #expect(selected == lastClosed)
}

@Test
func codexDesktopAppURLFallsBackToChatGPTBeforeCodex() {
    let missingLastClosed = URL(fileURLWithPath: "/Applications/Old Codex.app", isDirectory: true)
    let chatGPT = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
    let codex = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)

    let selected = codexDesktopAppURL(
        lastClosedBundleURL: missingLastClosed,
        fallbackAppURLs: [chatGPT, codex],
        fileExists: { $0 == chatGPT.path || $0 == codex.path }
    )

    #expect(selected == chatGPT)
}

@Test
func codexDesktopAppURLFallsBackToCodexWhenChatGPTIsMissing() {
    let chatGPT = URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true)
    let codex = URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)

    let selected = codexDesktopAppURL(
        lastClosedBundleURL: nil,
        fallbackAppURLs: [chatGPT, codex],
        fileExists: { $0 == codex.path }
    )

    #expect(selected == codex)
}

@Test
func codexDesktopAppURLReturnsNilWhenNoKnownAppExists() {
    let selected = codexDesktopAppURL(
        lastClosedBundleURL: URL(fileURLWithPath: "/Applications/ChatGPT.app", isDirectory: true),
        fallbackAppURLs: [URL(fileURLWithPath: "/Applications/Codex.app", isDirectory: true)],
        fileExists: { _ in false }
    )

    #expect(selected == nil)
}
