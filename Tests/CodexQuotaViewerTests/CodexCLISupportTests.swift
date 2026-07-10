import Foundation
import Testing

@testable import CodexQuotaViewer

private func makeExecutableCodex(named directoryName: String) throws -> (root: URL, executable: URL) {
    let fileManager = FileManager.default
    let root = fileManager.temporaryDirectory
        .appendingPathComponent("\(directoryName)-\(UUID().uuidString)", isDirectory: true)
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

    let executable = root.appendingPathComponent("codex", isDirectory: false)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable, options: .atomic)
    try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
    return (root, executable)
}

@Test
func codexCLIResolutionUsesFallbackExecutableWhenGUIPathIsMissingHomebrew() throws {
    let fallback = try makeExecutableCodex(named: "fallback-codex")
    defer { try? FileManager.default.removeItem(at: fallback.root) }

    let configuration = resolveCodexCLIConfiguration(
        bundledExecutableURL: URL(fileURLWithPath: "/missing/Codex.app/Contents/Resources/codex"),
        fallbackExecutableURLs: [fallback.executable],
        environment: ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
    )

    #expect(configuration?.executableURL == fallback.executable)
    #expect(configuration?.argumentsPrefix == [])
}

@Test
func codexCLIResolutionPrefersPathExecutableOverFallbackExecutable() throws {
    let pathExecutable = try makeExecutableCodex(named: "path-codex")
    let fallback = try makeExecutableCodex(named: "fallback-codex")
    defer {
        try? FileManager.default.removeItem(at: pathExecutable.root)
        try? FileManager.default.removeItem(at: fallback.root)
    }

    let configuration = resolveCodexCLIConfiguration(
        bundledExecutableURL: URL(fileURLWithPath: "/missing/Codex.app/Contents/Resources/codex"),
        fallbackExecutableURLs: [fallback.executable],
        environment: ["PATH": pathExecutable.root.path]
    )

    #expect(configuration?.executableURL == pathExecutable.executable)
}
