#!/bin/sh
# Build KeyLock.app. A bundle (not a bare binary) so Accessibility permission
# attaches to KeyLock itself instead of whatever terminal launched it.
set -e
cd "$(dirname "$0")"
VERSION=1.3.0          # bump this, then tag the GitHub release v$VERSION
REPO="nixentric/keylock" # "owner/keylock" — leave empty to switch the update check off
APP=KeyLock.app
rm -rf "$APP" build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O Sources/*.swift -o "$APP/Contents/MacOS/KeyLock"

# Icon from logo.png. Composited with AppKit, not sips: the source is 1120x1194 and
# sips can only pad with an opaque colour, which turns the transparent corners black.
if [ -f logo.png ]; then
  mkdir -p build/AppIcon.iconset
  cat > build/makeicon.swift <<'SWIFT'
import AppKit
let side = 1024, inset = 0.92  // margin the macOS icon grid expects; icon looks oversized without it
let src = NSImage(contentsOfFile: "logo.png")!
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                           colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let scale = Double(side) * inset / max(src.size.width, src.size.height)
let w = src.size.width * scale, h = src.size.height * scale
src.draw(in: NSRect(x: (Double(side) - w) / 2, y: (Double(side) - h) / 2, width: w, height: h))
NSGraphicsContext.restoreGraphicsState()
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "build/icon.png"))
SWIFT
  swift build/makeicon.swift
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon.png --out "build/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s * 2)) $((s * 2)) build/icon.png \
      --out "build/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns build/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
  cp logo.png "$APP/Contents/Resources/"  # the launcher shows it too
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>KeyLock</string>
  <key>CFBundleExecutable</key><string>KeyLock</string>
  <key>CFBundleIdentifier</key><string>local.keylock</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>KLUpdateRepo</key><string>$REPO</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
</dict></plist>
PLIST
# TCC ties the Accessibility grant to the signature. A stable signing identity keeps the
# permission across rebuilds; an ad-hoc one is a different app every time, so the old grant
# lingers switched on while no longer applying — which looks exactly like a broken app.
# See README "Keeping the permission across rebuilds" to create the identity.
IDENTITY=$(security find-identity -v -p codesigning 2>/dev/null |
    sed -n 's/.*"\(KeyLock Local\)".*/\1/p' | head -1)
if [ -n "$IDENTITY" ]; then
  codesign --force --sign "$IDENTITY" "$APP"
  echo "signed with '$IDENTITY' — Accessibility grant survives this rebuild"
else
  codesign --force --sign - "$APP"
  tccutil reset Accessibility local.keylock >/dev/null 2>&1 || true
  echo "ad-hoc signed — grant Accessibility again after this build"
fi
touch "$APP"  # nudge Finder/Dock off the cached icon
"$APP/Contents/MacOS/KeyLock" --selftest

# Installer: drag-to-Applications disk image.
mkdir -p build/dmg
cp -R "$APP" build/dmg/
ln -s /Applications build/dmg/Applications
rm -f KeyLock.dmg
hdiutil create -volname KeyLock -srcfolder build/dmg -ov -format UDZO -quiet KeyLock.dmg

echo "built $PWD/$APP and $PWD/KeyLock.dmg"
