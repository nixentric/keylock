# KeyLock

<img src="logo.png" width="120" align="right" alt="KeyLock">

Kunci keyboard MacBook selama beberapa menit supaya bisa dilap tanpa mengetik hal
aneh ke mana-mana. Mouse/trackpad tetap hidup — itu satu-satunya jalan membuka kunci.

macOS tidak punya fitur ini bawaan. KeyLock memakai `CGEventTap` untuk menelan
semua event `keyDown`, `keyUp`, dan `flagsChanged`. Satu file Swift, tanpa
dependency, tanpa Homebrew, tanpa background daemon — event tap-nya mati bersama
prosesnya.

## Install

**Cara cepat:** unduh `KeyLock.dmg` dari halaman
[Releases](https://github.com/nixentric/keylock/releases), buka, seret KeyLock ke
Applications.

Build ad-hoc signed, jadi saat pertama dibuka Gatekeeper mungkin menolak. Klik
kanan ikonnya › **Open** › **Open**, atau:

```bash
xattr -dr com.apple.quarantine /Applications/KeyLock.app
```

## Build sendiri

Butuh Xcode Command Line Tools (`xcode-select --install`). Tidak butuh Xcode penuh.

```bash
git clone https://github.com/nixentric/keylock.git
cd keylock
./build.sh
```

Hasilnya `KeyLock.app` dan `KeyLock.dmg` di folder yang sama. `build.sh`
mengerjakan: compile `keylock.swift` dengan `swiftc`, komposit `logo.png` jadi
`AppIcon.icns`, tulis `Info.plist`, ad-hoc codesign, jalankan self-test, lalu
bungkus jadi disk image.

Dua variabel di atas [`build.sh`](build.sh) yang biasanya diubah:

| Variabel  | Isinya                                                          |
| --------- | --------------------------------------------------------------- |
| `VERSION` | Versi bundle, dipakai untuk membandingkan dengan rilis terbaru    |
| `REPO`    | `owner/repo` untuk cek update. Kosongkan untuk mematikan cek ini  |

## Izin Accessibility

Memblokir keyboard butuh izin Accessibility. Buka KeyLock pertama kali dan ia
menampilkan layar pengaktifan: klik **Buka System Settings**, nyalakan sakelar
KeyLock di Privacy & Security › Accessibility, lalu kembali. Layar kunci jalan
sendiri begitu izinnya masuk — tidak perlu buka ulang aplikasinya.

Izin ini terikat ke salinan aplikasi tertentu. Habis rebuild atau habis
memindahkan app ke folder lain, sakelarnya perlu dinyalakan ulang.

## Pakai

Buka KeyLock. Layar menghitam, keyboard mati, dan sisa waktunya tampil di layar.

**Buka kunci:** tahan tombol *Hold to unlock* selama 1,5 detik. Sengaja tahan,
bukan klik — supaya lap yang menyenggol trackpad tidak ikut membuka kunci.
Kalau tidak diapa-apakan, kuncinya lepas sendiri setelah waktunya habis.

Durasi default 5 menit. Untuk mengubahnya:

```bash
open -a KeyLock --args --seconds 120
```

Selama terkunci, Dock, menu bar, dan pindah aplikasi semuanya mati
(`NSApplicationPresentationOptions`), jadi jangan set `--seconds` kelewat besar.

**Yang tidak bisa diblokir:** tombol power, Touch ID, dan force-restart tahan
power. Itu level hardware, di bawah jangkauan event tap. Jangan menekan area itu
saat mengelap.

## Cek update

Saat dibuka, KeyLock menanyakan rilis terbaru ke GitHub
(`/repos/OWNER/REPO/releases/latest`) dan membandingkan `tag_name` dengan versi
bundle. Kalau ada yang lebih baru, satu baris pemberitahuan muncul di layar
kunci. Asinkron, jadi tidak menunda penguncian, dan diam saja kalau offline.
Bukan auto-update — unduhannya tetap manual dari halaman Releases.

## Rilis versi baru

```bash
gh release create v1.1.0 KeyLock.dmg --title "KeyLock 1.1.0" --notes "Apa yang berubah"
```

Naikkan `VERSION` di `build.sh` dulu, jalankan `./build.sh`, baru bikin rilisnya.
Tag harus cocok dengan `VERSION` supaya pembandingnya benar.

## Test

```bash
KeyLock.app/Contents/MacOS/KeyLock --selftest
```

Memeriksa event mana yang ditelan, parsing `--seconds`, dan pembanding versi.
`build.sh` menjalankannya tiap build.

## Lisensi

MIT
