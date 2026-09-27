# app_amiberry - developer context

**Amiberry-Lite** packaged as **one AutoBleem App**, one zip per platform (`dist/amiberry-<key>-<version>.zip`, laid
out as `Apps/amiberry/`), in the multi-platform App format (the launcher's `docs/app-format-plan.md`). Store id
`app/amiberry` - the RetroBoot App's folder and id, so the Store updates it in place on psc. **psc, rpi, rpi64,
pcusb - no Windows package.**

Started 2026-09-25, the eighth and last third-party App port (autobleem-main `docs/decisions.md`, "Third-party
App ports" - the rules; `app_opentyrian`'s CLAUDE.md is the template). The 2019 PlayStation Classic port is
`screemerpl/amiberry-psc` (archived, Amiberry 3.0.4): its pad layout and its "for AutoBleem" branding carried
over; its icon (the Amiga checkmark - a trademark) did not.

## The owner's decisions for this port (2026-09-25)

- **Amiberry-Lite, no Windows.** The current Amiberry (8.x) is built on **SDL3**, which the console cannot run
  (Weston 1.11 offers only `wl_shell`, which SDL3 has no window for - the same ceiling that keeps the launcher at
  SDL 2.0.14). Amiberry-Lite is upstream's SDL2 line for low-end machines, **Linux-only**; Windows users have
  WinUAE. An exception to "every target" - the owner's call. Upstream: `BlitterStudio/amiberry-lite` at
  **`v5.9.3`**, the package version `5.9.3-2` (`VERSION`).
- **Data**: AROS (the built-in replacement Kickstart, `roms/aros-*.bin`) and WHDLoad (`whdboot/`) - what
  upstream ships. No Kickstarts, no games; the readme says where the user's own go.
- **Start in Amiberry's GUI** (its Quickstart page), driven with the pad. Its menu (`main_window.cpp`) takes a
  step on a hat event *and* on a LEFTX/LEFTY axis event, so the virtual pad's default `movement = both` (the D-pad
  also moves the left stick) made every D-pad press two steps: `pad.ini` sets `movement = as-is` (5.9.3-2, tested
  on the console 2026-09-26; the Amiga joystick reads the D-pad too). 5.9.3-1's 5-8 steps per press were the
  console's SDL 2.0.4 - launcher nightly 157's `app_env.sh` - not Amiberry.
- **The 2019 pad layout**: D-pad joystick, Cross fire, Circle Return, Square Space, Triangle the left mouse
  button, Start swaps the joystick ports, Select the GUI; L1/R1 keep upstream's Space/Return.
- **Our branding**: the About panel's logo with the AutoBleem logo in its corner, and a credits line.

## Layout

| path | what |
|---|---|
| `upstream/amiberry-lite` | the pinned emulator (submodule, `v5.9.3`) |
| `upstream/{zlib,libpng,flac,zstd}` | its libraries, pinned (zlib 1.3.1, libpng 1.6.58, FLAC 1.5.0, zstd 1.5.7), built static per target and linked in |
| `patches/amiberry-lite/0001-autobleem-credits.patch` | a credits line in the About panel |
| `patches/amiberry-lite/0002-autobleem-defaults.patch` | `options.h`: Select (`back`) opens the GUI (a keyboard keeps F12), the emulation full-window; `main_window.cpp`: the GUI full-window everywhere, not only under KMSDRM; `amiberry_input.cpp`: the 2019 buttons in the "extra default mappings" block - plain joystick mode only, and only where the config has no custom mapping (CD32 and mouse modes stay upstream's) |
| `patches/amiberry-lite/0003-i686-sigsegv-headers.patch` | 32-bit x86 (the PC stick) takes `<sys/ucontext.h>` as x86_64 does; upstream sends it to 32-bit ARM's `<asm/sigcontext.h>`, which clashes with `<signal.h>` there |
| `resources/psc/glibc_compat.{h,c}` | the console build's compat for gcc-12 against glibc 2.24 (below) |
| `resources/app/` | `app.ini` (`Exec=bin/{key}/amiberry-lite`, `VirtualPad=true`, no `Args`/`Lib`), `readme.txt`, `icon.png`, `pad.ini` (`movement = as-is` - see below) |
| `resources/branding/` | `amiberry-logo.png` (the About panel's, copied over `data/`), drawn by `tools/make_branding.py` from Amiberry's logo and `autobleem-logo.png` (the launcher's `ablogo.png`) |
| `ci/build.sh` | `native|psc|rpi|rpi64|pcusb|all`: per target the libraries into `build_<key>/deps` (kept while `deps/.stamp` matches), then a copy of Amiberry, the patches, upstream's CMake with serial/MIDI/libmpeg2/enet/mpg123/pcap off, zstd on; stages the portable App folder and checks it |
| `tools/store_item.py`, `tools/zip_app.py` | as in the other ports |
| `/opt/ab/tools/check_psc_binary.sh`, `/opt/ab/tools/check_needed.sh` (autobleem-build image) | no longer vendored (APPS-6) - as in the other ports; `check_needed.sh` is passed `plugins/*.so*` as its 3rd argument to also check the plugins |

## Things to know

- **The console's compiler.** Amiberry-Lite is C++17 with `std::filesystem`; the console's gcc-6 cannot build it.
  `target_psc` uses the image's **gcc-12** (Debian's `arm-linux-gnueabihf-g++`) against the **Stretch sysroot**
  (`/opt/psc/sysroot`, glibc 2.24): `-nostdinc` with gcc-12's C++ headers and the sysroot's C headers only (the
  compiler would otherwise search Bookworm's armhf glibc under `/usr/arm-linux-gnueabihf` first and the binary
  would want GLIBC_2.36), the sysroot's libraries first (`-B`/`-L`), **libstdc++ and libgcc static**, and
  `glibc_compat.o` for what that libstdc++ and the gcc-12 headers call beyond glibc 2.24:
  `__libc_single_threaded` (always 0), `getentropy`/`arc4random` (the `getrandom` syscall), and the five
  `pthread_*clock*`/`sem_clockwait` waits (as `timed` waits on CLOCK_REALTIME; the header is force-included into
  every C++ file for their declarations). `--exclude-libs,ALL` keeps each plugin's static libstdc++ to itself.
  `check_psc_binary.sh` holds the program and both plugins to GLIBC 2.24 and no GLIBCXX (today: 2.18/2.17).
  Three more things the first builds turned up: `-pthread` on every link (glibc 2.24 keeps the timed waits in
  libpthread) and `-lutil` at the end of Amiberry's (`CMAKE_CXX_STANDARD_LIBRARIES` - `forkpty`, after
  upstream's `--as-needed`); `-mfpu=neon-fp-armv8`, not the other ports' `neon-vfpv4`; and FLAC built with
  `-fno-tree-vectorize` - gcc-12 has an internal compiler error vectorising its window functions for 32-bit
  NEON. The console binary ran on the Pi 400's 32-bit userland on 2026-09-25 (`-h`, and ten seconds of the GUI
  with SDL's dummy drivers) - the static libstdc++ and the compat symbols load.
- **Portable mode**: `amiberry.portable` in the working directory (the App folder - the launcher starts an App
  there) puts everything under it: `data/`, `conf/` (`amiberry-lite.conf`, `default.uae` - the config loaded at
  start), `roms/`, `whdboot/`, `controllers/` (upstream's `gamecontrollerdb.txt`), `floppies/`, `lha/`,
  `harddrives/`, `savestates/`, `screenshots/`, `plugins/` (`libcapsimage.so` - IPF images - and
  `libfloppybridge.so` - real floppy drives). **Lower case**: those are Linux's names; the capitalised ones in
  upstream's `init_amiberry_dirs` are the macOS build's (a first staging with them had Amiberry make its own
  `whdboot/` and `controllers/` beside ours on a case-sensitive filesystem). The user's settings are never in the package, so a Store update
  keeps them; our defaults are patched into the source for that reason.
- **Leaving**: Select, then Quit; Reset on the console; the Start+Select hold.
- **Build on the server**: sync with MSYS2's rsync (excluding `/build_*`, `/dist`), then
  `docker run --rm -u $(id -u):$(id -g) -v $PWD:/src -w /src ghcr.io/autobleem2/autobleem-build:develop ci/build.sh all`;
  remove `build_*`/`dist` there afterwards.
- **Releases**: a `v<version>` tag (`v5.9.3-1`) builds a stable GitHub release with the four zips (in the release
  image, `autobleem-build:latest`); `master` follows the released commit. The Store gets it by hand:
  `gh release download <tag>`, `tools/store_item.py` per zip, then autobleem-repo's
  `repo_publish.sh store <key> dist/store/<key>/*` - psc, rpi, rpi64, pcusb.
- **Run on the owner's console** (2026-09-26, 5.9.3-2: the menu, one step per D-pad press); not yet on a Pi or the PC
  stick (the tester checklist, section 12).
