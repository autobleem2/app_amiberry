#!/usr/bin/env python3
"""Draw the App's pictures (checked in; needs Pillow):

    tools/make_branding.py

- resources/branding/amiberry-logo.png - what the About panel shows (data/amiberry-logo.png, 468x200, which
  ci/build.sh replaces with it): Amiberry's own logo with the AutoBleem logo (resources/branding/
  autobleem-logo.png, the launcher's ablogo.png) in its lower right corner - the 2019 port's "for AutoBleem".
- resources/app/icon.png (256x219, what the launcher's Apps set shows): Amiberry's own icon (data/amiberry.png).
  The 2019 App's icon, the Amiga checkmark, is a trademark and not used.
"""
import os

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
DATA = os.path.join(ROOT, "upstream", "amiberry-lite", "data")
BRANDING = os.path.join(ROOT, "resources", "branding")


def logo():
    base = Image.open(os.path.join(DATA, "amiberry-logo.png")).convert("RGBA")
    mark = Image.open(os.path.join(BRANDING, "autobleem-logo.png")).convert("RGBA")
    width = 108
    mark = mark.resize((width, round(mark.height * width / mark.width)), Image.LANCZOS)
    x, y = base.width - mark.width - 6, base.height - mark.height - 4
    # a soft plate under it, so the white lettering reads on the logo's light rays
    plate = Image.new("RGBA", (mark.width + 8, mark.height + 6), (20, 30, 70, 150))
    base.alpha_composite(plate, (x - 4, y - 3))
    base.alpha_composite(mark, (x, y))
    out = os.path.join(BRANDING, "amiberry-logo.png")
    base.save(out, optimize=True)
    print(out)


def icon():
    art = Image.open(os.path.join(DATA, "amiberry.png")).convert("RGBA")
    art = art.resize((219, 219), Image.LANCZOS)
    out_img = Image.new("RGBA", (256, 219), (0, 0, 0, 0))
    out_img.alpha_composite(art, ((256 - 219) // 2, 0))
    out = os.path.join(ROOT, "resources", "app", "icon.png")
    out_img.save(out, optimize=True)
    print(out)


if __name__ == "__main__":
    logo()
    icon()
