import AppKit
import Observation
import OSLog
import PensumCore

/// Sucht einmal am Tag bei GitHub nach einer neueren Version und installiert sie auf Wunsch.
/// Die einzige Verbindung ins Netz, abschaltbar in den Einstellungen.
@Observable
final class Updater {
    struct Release: Equatable {
        let version: String
        let page: URL
        let archive: URL
    }

    enum State: Equatable {
        case idle
        case available(Release)
        case installing(Release)
        case failed(Release)
    }

    private(set) var state: State = .idle

    private static let latestURL = URL(string: "https://api.github.com/repos/maxikuehn/pensum/releases/latest")!
    private static let lastCheckKey = "lastUpdateCheck"
    private let current = AppVersion(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
    private var isChecking = false

    /// Entwicklungs-Builds suchen nur mit `-updateCheck YES`, sonst würde ein Update den Build im Projektordner ersetzen.
    private var isEnabled: Bool {
        #if DEBUG
        guard UserDefaults.standard.bool(forKey: "updateCheck") else { return false }
        #endif
        return Preferences.updateCheckEnabled
    }

    /// Beim Start immer, danach bei der ersten Aktivität eines neuen Tages, also morgens.
    func check(now: Date = .now, onlyIfNewDay: Bool) {
        guard isEnabled, !isChecking, state == .idle else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckKey) as? Date
        if onlyIfNewDay, let last, Calendar.current.isDate(last, inSameDayAs: now) { return }
        UserDefaults.standard.set(now, forKey: Self.lastCheckKey)
        isChecking = true
        Task {
            defer { isChecking = false }
            do {
                guard let release = try await fetchNewerRelease() else { return }
                state = .available(release)
                #if DEBUG
                if UserDefaults.standard.bool(forKey: "installUpdate") { install(release) }
                #endif
            } catch {
                Logger.pensum.error("Suche nach Updates fehlgeschlagen: \(error)")
            }
        }
    }

    private func fetchNewerRelease() async throws -> Release? {
        var request = URLRequest(url: Self.latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let (data, _) = try await URLSession.shared.data(for: request)
        let latest = try JSONDecoder().decode(LatestRelease.self, from: data)
        guard AppVersion(latest.tagName) > current,
              let archive = latest.assets.first(where: { $0.name.hasSuffix(".zip") })
        else { return nil }
        return Release(version: AppVersion(latest.tagName).parts.map(String.init).joined(separator: "."),
                       page: latest.htmlURL, archive: archive.downloadURL)
    }

    /// Lädt die neue Version, prüft sie und übergibt an ein Skript, das nach dem Beenden die App austauscht und neu startet.
    func install(_ release: Release) {
        state = .installing(release)
        Task {
            do {
                let folder = FileManager.default.temporaryDirectory.appending(path: "Pensum-Update-\(UUID().uuidString)")
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                let (download, _) = try await URLSession.shared.download(from: release.archive)
                let archive = folder.appending(path: "Pensum.zip")
                try FileManager.default.moveItem(at: download, to: archive)
                try await Task.detached { try Self.run("/usr/bin/ditto", ["-x", "-k", archive.path, folder.path]) }.value

                let app = folder.appending(path: "Pensum.app")
                guard Bundle(url: app)?.bundleIdentifier == Bundle.main.bundleIdentifier else {
                    throw CocoaError(.fileReadCorruptFile)
                }
                try Self.launchReplacement(of: Bundle.main.bundleURL, with: app, cleaning: folder)
                NSApp.terminate(nil)
            } catch {
                Logger.pensum.error("Update konnte nicht installiert werden: \(error)")
                state = .failed(release)
            }
        }
    }

    /// Wartet im Hintergrund, bis Pensum beendet ist, ersetzt dann die App und startet sie neu.
    /// Klappt das Kopieren nicht, bleibt die alte Version erhalten und startet wieder.
    private static func launchReplacement(of target: URL, with app: URL, cleaning folder: URL) throws {
        let script = """
        while kill -0 "$1" 2>/dev/null; do sleep 0.2; done
        if ditto "$3" "$2.update"; then
            rm -rf "$2" && mv "$2.update" "$2"
        fi
        rm -rf "$2.update" "$4"
        xattr -dr com.apple.quarantine "$2" 2>/dev/null
        open "$2"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, "pensum-update",
                             String(ProcessInfo.processInfo.processIdentifier), target.path, app.path, folder.path]
        try process.run()
    }

    nonisolated private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}

/// Die Felder aus der GitHub-Antwort zum neuesten Release, die Pensum braucht.
private struct LatestRelease: Decodable {
    struct Asset: Decodable {
        let name: String
        let downloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case downloadURL = "browser_download_url"
        }
    }

    let tagName: String
    let htmlURL: URL
    let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
