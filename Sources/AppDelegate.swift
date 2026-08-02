import Cocoa

/// Wiring: launcher → event tap → lock screen → quit. Also the kiosk clamp, which only ever
/// applies while locked; on the launcher it fought System Settings for focus.

func parseSeconds(_ args: [String]) -> Int {
    guard let i = args.firstIndex(of: "--seconds"), i + 1 < args.count,
          let n = Int(args[i + 1]), n > 0 else { return savedMinutes() * 60 }
    return n
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tap = KeyboardTap()
    private var launcher: Launcher?
    private var lockScreen: LockScreen?
    private var locked = false

    func applicationDidFinishLaunching(_ note: Notification) {
        // --autostart is the relaunch path below, where the duration was already chosen.
        if CommandLine.arguments.contains("--autostart") {
            startLock(seconds: parseSeconds(CommandLine.arguments))
            return
        }
        let launcher = Launcher { [weak self] seconds in self?.startLock(seconds: seconds) }
        self.launcher = launcher
        launcher.show(defaultMinutes: savedMinutes())
    }

    private func startLock(seconds: Int) {
        locked = true  // set before closing the launcher, or the last-window-closed rule quits us
        guard tap.start() else {
            relaunchOrFail(seconds: seconds)
            return
        }
        let screen = LockScreen(seconds: seconds) { [weak self] in self?.unlock() }
        screen.show()
        lockScreen = screen
        launcher?.close()
        launcher = nil

        NSApp.activate(ignoringOtherApps: true)
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]
        checkForUpdate { [weak self] text in self?.lockScreen?.setNote(text) }
    }

    private func unlock() {
        locked = false
        NSApp.presentationOptions = []
        tap.stop()
        NSApp.terminate(nil)
    }

    /// Granting Accessibility does not always reach an already-running process, but a fresh
    /// launch always gets it. Retry once, then say so instead of pretending to lock.
    private func relaunchOrFail(seconds: Int) {
        guard !CommandLine.arguments.contains("--relaunched") else {
            let alert = NSAlert()
            alert.messageText = "Could not lock the keyboard"
            alert.informativeText = "The event tap was refused. Check Accessibility permission for KeyLock."
            alert.runModal()
            NSApp.terminate(nil)
            return
        }
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = ["--relaunched", "--autostart", "--seconds", String(seconds)]
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    func applicationDidBecomeActive(_ note: Notification) {
        guard locked else { return }
        NSApp.presentationOptions = [.hideDock, .hideMenuBar, .disableProcessSwitching]
    }

    func applicationDidResignActive(_ note: Notification) {
        guard locked else { return }
        NSApp.activate(ignoringOtherApps: true)
        lockScreen?.bringToFront()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { !locked }
}
