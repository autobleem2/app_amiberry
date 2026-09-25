Amiberry
========

Amiberry is an emulator of the Commodore Amiga - the A500, A1200, CD32 and the rest - built on WinUAE. This is
Amiberry-Lite, its edition for smaller machines, with a 68000 JIT on the PlayStation Classic and the Raspberry
Pi.

It opens in its own menu. Pick a machine on the Quickstart page (A500 for most games, A1200 for AGA games), put
a disk in the drive and press Start. The pad drives the menu: D-Pad to move, Cross to choose.


Kickstart ROMs and games
------------------------

An Amiga needs its Kickstart ROM. The App comes with AROS, the free replacement Kickstart Amiberry includes -
enough for a number of games, not for all. The original Kickstarts are copyrighted; if you own them (from your
own Amiga, or bought as Amiga Forever from Cloanto), copy them into Apps/amiberry/roms (kick13.rom for the
A500, kick31.rom for the A1200) and press "Rescan Paths" on the Paths page.

No games are included. Put your own:

  Apps/amiberry/floppies     disk images (.adf, .adz, .dms, .ipf)
  Apps/amiberry/lha          WHDLoad games (.lha) - started straight from the menu, no disks to swap
  Apps/amiberry/harddrives   hard drive images and folders

WHDLoad itself is included (whdboot/); WHDLoad games want a real Kickstart 1.3 and 3.1 in roms.


Controls
--------

D-Pad / left stick   Joystick
Cross                Fire
Circle               Return (the Amiga's Enter key)
Square               Space
Triangle             Left mouse button
Start                Swap the joystick ports (for a game that reads port 1)
Select               The Amiberry menu - change disks, save a state, quit
L1 / R1              Space / Return

A USB keyboard and mouse work too, where the machine takes them. F12 opens the menu from a keyboard.

To leave: Select, then Quit. Or press Reset on the console, or hold Start + Select.

The settings, save states and screenshots are kept in this folder.


Credits
-------

Amiberry: Dimitris Panokostas (MiDWaN) and BlitterStudio - https://github.com/BlitterStudio/amiberry-lite
(GPL-3.0, see LICENSE-amiberry.txt); WinUAE: Toni Wilen and contributors. AROS: the AROS Development Team.
WHDLoad: Wepl and contributors.
PlayStation Classic port (2019) and this App: Artur Jakubowicz (screemer) and the AutoBleem team.
Built in: zlib, libpng, FLAC, zstd, mt32emu, the CAPS image library (see licences/).
