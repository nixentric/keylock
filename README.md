# KeyLock

<img src="logo.png" width="120" align="right" alt="KeyLock">

Lock your MacBook keyboard for a few minutes so you can wipe it down without
typing nonsense into whatever is open. The mouse and trackpad stay live — that
is the only way back out.

macOS has no built-in way to do this. KeyLock installs a `CGEventTap` that
swallows every `keyDown`, `keyUp`, and `flagsChanged` event. One Swift file, no
dependencies, no Homebrew, no background daemon — the tap dies with the process.

## Install

**Quick way:** grab `KeyLock.dmg` from
[Releases](https://github.com/nixentric/keylock/releases), open it, drag KeyLock
into Applications.

The build is ad-hoc signed, so Gatekeeper will block the first launch. Right
click the icon › **Open** › **Open**, or:

```bash
xattr -dr com.apple.quarantine /Applications/KeyLock.app
```

## Build it yourself

Needs the Xcode Command Line Tools (`xcode-select --install`). Full Xcode is not
required.

```bash
git clone https://github.com/nixentric/keylock.git
cd keylock
./build.sh
```

You get `KeyLock.app` and `KeyLock.dmg` in the same folder. `build.sh` compiles
`Sources/*.swift` with `swiftc`, composites `logo.png` into `AppIcon.icns`, writes
`Info.plist`, ad-hoc signs the bundle, runs the self-test, and wraps it all in a
disk image.

| File                       | What lives there                                    |
| -------------------------- | --------------------------------------------------- |
| `Sources/main.swift`       | Entry point and `--selftest` branch                  |
| `Sources/Launcher.swift`   | Launcher window: duration picker, permission gate    |
| `Sources/DialView.swift`   | The circular dial: ring, editable readout, drag maths|
| `Sources/EventTap.swift`   | The lock itself, a `CGEventTap` eating key events    |
| `Sources/LockScreen.swift` | Black overlays, countdown, hold-to-unlock button     |
| `Sources/UpdateCheck.swift`| Latest GitHub release vs this build                  |
| `Sources/AppDelegate.swift`| Wires the above together, kiosk clamp while locked   |
| `Sources/SelfTest.swift`   | Assertions run on every build                        |

Two variables at the top of [`build.sh`](build.sh) are the ones worth editing:

| Variable  | What it does                                                     |
| --------- | ---------------------------------------------------------------- |
| `VERSION` | Bundle version, compared against the latest release tag           |
| `REPO`    | `owner/repo` for the update check. Leave empty to turn it off     |

## Use it

Open KeyLock and the launcher appears: drag around the dial to set how long to
lock for (1–120 minutes, remembered for next time), or click the `00:05:00`
readout and type it — `25`, `0:45` and `01:30:00` all work. Then press
**Start lock**. The screen goes dark, the
keyboard goes dead, and the remaining time is shown on screen.

Nothing is locked until you press Start, so the launcher is the last screen where
your keyboard still works.

**To unlock:** hold the *Hold to unlock* button for 1.5 seconds. A deliberate
hold, not a click, so a cloth brushing the trackpad cannot let you out. Leave it
alone and the lock lifts by itself when the timer runs out.

While locked, the Dock, the menu bar, and app switching are all disabled
(`NSApplicationPresentationOptions`), so pick a duration you are willing to sit
through.

**What it cannot block:** the power button, Touch ID, and a hold-to-force-restart.
Those live below the event tap, in hardware. Keep the cloth away from them.

### Accessibility permission

Blocking the keyboard requires Accessibility access. Until it is granted, the
launcher disables Start and shows an **Open System Settings** button. Flip the
KeyLock switch under Privacy & Security › Accessibility and come back — Start
lights up on its own, no relaunch needed.

The grant is tied to that exact copy of the app. After a rebuild, or after moving
the app somewhere else, flip the switch again.

## Update check

On launch KeyLock asks GitHub for the latest release
(`/repos/OWNER/REPO/releases/latest`) and compares `tag_name` against the bundle
version. If something newer exists, one notice line appears on the lock screen.
It runs asynchronously so it never delays the lock, and stays quiet when offline.
This is not auto-update — downloading is still a manual trip to Releases.

## Cutting a release

```bash
gh release create v1.1.0 KeyLock.dmg --title "KeyLock 1.1.0" --notes "What changed"
```

Bump `VERSION` in `build.sh` first, run `./build.sh`, then cut the release. The
tag has to match `VERSION` or the comparison is meaningless.

## Tests

```bash
KeyLock.app/Contents/MacOS/KeyLock --selftest
```

Covers which events get swallowed, `--seconds` parsing, and version comparison.
`build.sh` runs it on every build.

## License

MIT
