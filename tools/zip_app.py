#!/usr/bin/env python3
"""tools/zip_app.py <zip> <Apps/name>: every file under the App's folder, sorted, with its mode (the program stays
executable where the filesystem keeps it). Run from the folder that holds Apps/. Only the standard library."""
import os
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for root, dirs, files in os.walk(sys.argv[2]):
        dirs.sort()
        for name in sorted(files):
            z.write(os.path.join(root, name))
        if not files and not dirs:  # an empty folder the App expects (Saves/)
            z.write(root)
