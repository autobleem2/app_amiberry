# app_amiberry

[Amiberry-Lite](https://github.com/BlitterStudio/amiberry-lite), the Commodore Amiga emulator, packaged as an
[AutoBleem](https://github.com/autobleem2/autobleem) App for the PlayStation Classic, the Raspberry Pi and the
AutoBleem PC stick - with the AutoBleem branding of the 2019 PlayStation Classic port.

Install it from the AutoBleem Store. It comes with AROS (the free replacement Kickstart) and WHDLoad; your own
Kickstart ROMs go in `Apps/amiberry/roms`, disk images in `floppies`, WHDLoad games in `lha`. There is no Windows
package - Amiberry-Lite is Linux-only (WinUAE is the Windows emulator).

The upstream source and its libraries are pinned submodules; this repository holds only the build
(`ci/build.sh`, run in the [autobleem-build](https://github.com/autobleem2/autobleem-build) image), three patches
(the credits; the pad layout, full screen and Select for the menu; a header fix for 32-bit x86) and the App's files.

```
git clone --recurse-submodules https://github.com/autobleem2/app_amiberry
ci/build.sh all    # inside ghcr.io/autobleem2/autobleem-build
```

Controls (PlayStation Classic pad): D-pad joystick, Cross fire, Circle Return, Square Space, Triangle left mouse
button, Start swaps the joystick ports, Select the menu. Press Reset on the console or hold Start + Select to
leave.

Licence: the build, patches and tools GPL-3.0-or-later; Amiberry GPL-3.0; the bundled parts their own - see
`LICENSE`.
