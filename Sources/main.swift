import Cocoa

// KeyLock — lock the MacBook keyboard while you wipe it down.
//
//   Launcher.swift    pick a duration, grant Accessibility
//   DialView.swift    the launcher's dial: drag or type a duration
//   Ring.swift        shared ring drawing, plus the lock screen countdown
//   EventTap.swift    the lock itself, a CGEventTap that eats key events
//   LockScreen.swift  black overlay, countdown ring, hold-to-unlock
//   UpdateCheck.swift latest GitHub release vs this build
//   AppDelegate.swift wires those together
//   SelfTest.swift    --selftest, run on every build

if CommandLine.arguments.contains("--selftest") {
    runSelfTest()
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.regular)
app.run()
