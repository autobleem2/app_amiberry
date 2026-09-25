#!/usr/bin/env python3
"""Write the AutoBleem Store's descriptor for one platform's package of the Amiberry App (autobleem-repo
CLAUDE.md, "The AutoBleem Store's catalog"), next to the package and its picture, ready for
`repo_publish.sh store <platform> ...`:

    tools/store_item.py dist/amiberry-psc-5.9.3-1.zip  -> dist/store/psc/amiberry.item.json
                                                         + amiberry.png + the zip

The id is app/amiberry on every platform - the RetroBoot App's, so it is updated in place on psc. Only the
standard library is needed.
"""
import json
import os
import re
import shutil
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

ITEM = {
    "title": "Amiberry",
    "author": "Amiberry-Lite by Dimitris Panokostas (BlitterStudio), on WinUAE by Toni Wilen",
    "licence": "GPL-3.0 (AROS: the AROS Public License; WHDLoad: freeware)",
    "description": "The Commodore Amiga emulator - A500, A1200, CD32 - with AROS and WHDLoad. Your own "
                   "Kickstarts go in Apps/amiberry/roms, disks in floppies or lha.",
}


def main(argv):
    if len(argv) != 2:
        print(__doc__)
        return 2
    package = argv[1]
    m = re.match(r"^amiberry-(?P<key>[a-z0-9]+)-(?P<version>.+)\.zip$", os.path.basename(package))
    if not m:
        print("not an amiberry-<key>-<version>.zip: %s" % package)
        return 1
    key, version = m.group("key"), m.group("version")
    out = os.path.join(os.path.dirname(package), "store", key)
    os.makedirs(out, exist_ok=True)
    shutil.copy(package, out)
    shutil.copy(os.path.join(ROOT, "resources", "app", "icon.png"), os.path.join(out, "amiberry.png"))
    item = {
        "id": "app/amiberry",
        "kind": "app",
        "title": ITEM["title"],
        "version": version,
        "author": ITEM["author"],
        "licence": ITEM["licence"],
        "description": ITEM["description"],
        "image": "amiberry.png",
        "files": [{"name": os.path.basename(package)}],
    }
    with open(os.path.join(out, "amiberry.item.json"), "w", encoding="utf-8") as f:
        json.dump(item, f, indent=2)
        f.write("\n")
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
