import Cocoa

/// `KeyLock --selftest`, run on every build. Covers the pure logic: what gets swallowed,
/// how arguments and the duration field are read, and how versions compare.
func runSelfTest() {
    assert(shouldSwallow(.keyDown) && shouldSwallow(.keyUp) && shouldSwallow(.flagsChanged))
    assert(!shouldSwallow(.mouseMoved) && !shouldSwallow(.leftMouseDown) && !shouldSwallow(.scrollWheel))

    assert(isNewer("v1.2.0", than: "1.1.9") && isNewer("2.0", than: "1.9.9"))
    assert(!isNewer("v1.0.0", than: "1.0") && !isNewer("1.0", than: "1.0.1"))
    assert(!isNewer("", than: "1.0") && isNewer("1.2.0-beta", than: "1.1"))

    assert(parseSeconds(["--seconds", "90"]) == 90)
    assert(parseSeconds(["--seconds", "0"]) == savedMinutes() * 60)
    assert(parseSeconds(["--seconds"]) == savedMinutes() * 60)
    assert(parseSeconds([]) == savedMinutes() * 60)

    assert(clampMinutes(0) == 1 && clampMinutes(-5) == 1)
    assert(clampMinutes(999) == 120 && clampMinutes(7) == 7)
    assert((1 ... 120).contains(savedMinutes()))

    print("ok")
}
