import AppKit
import OSLog

/// Nach der Installation aus dem Disk-Image: Ist es noch eingebunden, bietet Pensum an,
/// es auszuwerfen und in den Papierkorb zu legen. Wer es behält, wird für dieses Image nicht noch einmal gefragt.
enum InstallerCleanup {
    private static let keptKey = "keptInstallerImage"

    private nonisolated struct Installer: Sendable {
        let image: URL
        let mountPoint: String
    }

    @MainActor
    static func offerIfNeeded() async {
        guard let installer = await Task.detached(operation: mountedInstaller).value,
              UserDefaults.standard.string(forKey: keptKey) != installer.image.path
        else { return }

        let alert = NSAlert()
        alert.messageText = "Disk-Image in den Papierkorb legen?"
        alert.addButton(withTitle: "In den Papierkorb")
        alert.addButton(withTitle: "Behalten")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else {
            UserDefaults.standard.set(installer.image.path, forKey: keptKey)
            return
        }

        await Task.detached { run("/usr/bin/hdiutil", ["detach", installer.mountPoint, "-quiet"]) }.value
        do {
            try await NSWorkspace.shared.recycle([installer.image])
        } catch {
            Logger.pensum.error("Disk-Image konnte nicht in den Papierkorb: \(error)")
        }
    }

    /// Ein eingebundenes Disk-Image, das eine Pensum-App enthält, solange Pensum nicht selbst von dort läuft.
    nonisolated private static func mountedInstaller() -> Installer? {
        guard let output = run("/usr/bin/hdiutil", ["info", "-plist"]),
              let info = try? PropertyListSerialization.propertyList(from: output, format: nil) as? [String: Any],
              let images = info["images"] as? [[String: Any]]
        else { return nil }

        let ownPath = Bundle.main.bundlePath
        for image in images {
            guard let path = image["image-path"] as? String,
                  let entities = image["system-entities"] as? [[String: Any]]
            else { continue }
            for mountPoint in entities.compactMap({ $0["mount-point"] as? String }) {
                guard !ownPath.hasPrefix(mountPoint + "/"),
                      let app = Bundle(path: mountPoint + "/Pensum.app"),
                      app.bundleIdentifier == Bundle.main.bundleIdentifier
                else { continue }
                return Installer(image: URL(fileURLWithPath: path), mountPoint: mountPoint)
            }
        }
        return nil
    }

    @discardableResult
    nonisolated private static func run(_ tool: String, _ arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            Logger.pensum.error("\(tool) ließ sich nicht starten: \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return process.terminationStatus == 0 ? data : nil
    }
}
