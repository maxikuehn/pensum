import AppKit
import SwiftUI

/// Öffnet man Pensum erneut, etwa über Spotlight oder den Programme-Ordner, während es schon in der Menüleiste läuft,
/// erscheint die Übersicht.
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Wird vom Menüleisten-Symbol gesetzt, das als einzige Ansicht von Anfang an besteht und Fenster öffnen kann.
    var openOverview: (() -> Void)?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openOverview?()
        return false
    }
}

/// Symbol in der Menüleiste; reicht nebenbei das Öffnen der Übersicht an den App-Delegate weiter.
struct MenuBarLabel: View {
    let state: MenuBarIcon.State
    let appDelegate: AppDelegate

    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Image(nsImage: MenuBarIcon.image(state))
            .onAppear {
                appDelegate.openOverview = {
                    openWindow(id: "overview")
                    NSApp.activate()
                }
            }
    }
}
