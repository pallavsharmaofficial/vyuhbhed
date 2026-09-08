"""Fetch six CC0 photographs and grade them into the app's palette.

The Atmosphere widget lays a colour veil and gradient fades over these, so a
photograph has to survive being tinted and still leave the middle of the frame
quiet enough to read text on. That means: crop to the phone's aspect, pull the
contrast and saturation down, and push the whole thing a little toward the
plum/lilac ground so a photo does not fight the UI it sits under.
"""
import json, io, urllib.parse, urllib.request
from PIL import Image, ImageEnhance, ImageOps

UA = "vyuhbhed-asset-fetch/1.0 (https://github.com/pallavsharmaofficial/vyuhbhed)"
OUT_W, OUT_H = 1080, 1920

# slot -> (Commons file title, why this image)
PICKS = {
    "welcome":  ("File:Silhouette mountain range and yellow sky (Unsplash).jpg",
                 "dawn over a ridgeline — the morning you decide to start"),
    "today":    ("File:Misty path (Unsplash).jpg",
                 "a path into fog: you can see the next few steps, not the end"),
    "working":  ("File:Night city traffic (Unsplash).jpg",
                 "light trails — effort in motion, the applications going out"),
    "aware":    ("File:Ominous clouds over mountains (Unsplash).jpg",
                 "weather coming in, for the screens that name a hard moment"),
    "calm":     ("File:Beautiful mountain reflection (Unsplash).jpg",
                 "still water — the day is done, close the app"),
    "origin":   ("File:China's mist mountain (Unsplash).jpg",
                 "distance and scale, for looking back at why you started"),
}

def api(params):
    url = "https://commons.wikimedia.org/w/api.php?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.load(r)

def fetch(title):
    d = api({
        "action": "query", "format": "json", "titles": title,
        "prop": "imageinfo", "iiprop": "url|extmetadata|size", "iiurlwidth": 2600,
    })
    page = list((d.get("query") or {}).get("pages", {}).values())[0]
    ii = page["imageinfo"][0]
    em = ii.get("extmetadata", {})
    lic = (em.get("LicenseShortName", {}).get("value") or "").strip()
    assert any(k in lic.lower() for k in ("cc0", "public domain", "no restrictions")), \
        f"{title}: refusing non-free licence {lic!r}"
    req = urllib.request.Request(ii.get("thumburl") or ii["url"], headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=180) as r:
        raw = r.read()
    return raw, {
        "title": title,
        "licence": lic,
        "artist": (em.get("Artist", {}).get("value") or "").replace("\n", " ")[:160],
        "source": ii.get("descriptionurl", ""),
    }

# Text sits directly on these under a translucent veil, so the photograph has
# to live inside a luminance window that keeps contrast >= 4.5:1 in BOTH
# themes. Derived from the actual veil colours in tokens.dart:
#   light  #F7F5F9 @ 42%  over the photo, ink #221D2B
#   dark   #171320 @ 50%  over the photo, ink #F1ECF5
# The window that satisfies both is 54..198; 80..171 leaves 5.5:1 of margin.
# We aim just inside it, which is why these read as soft rather than punchy —
# that is the constraint, not a stylistic accident.
SAFE_LO, SAFE_HI = 78, 178

def grade(raw):
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    # Cover-crop to 9:16 about the centre.
    target = OUT_W / OUT_H
    w, h = im.size
    if w / h > target:
        nw = int(h * target)
        im = im.crop(((w - nw) // 2, 0, (w - nw) // 2 + nw, h))
    else:
        nh = int(w / target)
        im = im.crop((0, (h - nh) // 2, w, (h - nh) // 2 + nh))
    im = im.resize((OUT_W, OUT_H), Image.LANCZOS)

    im = ImageEnhance.Color(im).enhance(0.5)
    # Spread to full range first, so every photo compresses from the same
    # starting point instead of inheriting its own exposure.
    im = ImageOps.autocontrast(im, cutoff=1)
    # Then squeeze into the readable window.
    span = SAFE_HI - SAFE_LO
    im = im.point(lambda v: SAFE_LO + (v * span) // 255)

    # A wash of the plum ground, so six photos from six places read as one app.
    tint = Image.new("RGB", im.size, (122, 76, 140))
    return Image.blend(im, tint, 0.16)

def contrast(path):
    """Worst-case contrast of body text over this image, light and dark."""
    im = Image.open(path).convert("L")
    w, h = im.size
    lo, hi = im.crop((0, int(h * 0.45), w, int(h * 0.90))).getextrema()

    def rel(l):
        c = l / 255
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4

    def ratio(a, b):
        a, b = rel(a), rel(b)
        x, y = max(a, b), min(a, b)
        return (x + 0.05) / (y + 0.05)

    light = min(ratio(32, 0.42 * 247 + 0.58 * v) for v in (lo, hi))
    dark = min(ratio(241, 0.50 * 23 + 0.50 * v) for v in (lo, hi))
    return light, dark


if __name__ == "__main__":
    credits = []
    for slot, (title, why) in PICKS.items():
        raw, meta = fetch(title)
        img = grade(raw)
        path = f"bg/bg-{slot}.jpg"
        img.save(path, "JPEG", quality=82, optimize=True, progressive=True)
        meta["slot"] = slot
        meta["why"] = why
        credits.append(meta)
        print(f"  {slot:<9} {meta['licence']:<16} {len(raw)//1024:>6} KB in -> {img.size}")
    with open("bg/CREDITS.json", "w") as f:
        json.dump(credits, f, indent=2)

    # Prove the readability claim rather than asserting it.
    print("\ncontrast of app text over each image (WCAG AA needs 4.5):")
    for slot in PICKS:
        lo, hi = contrast(f"bg/bg-{slot}.jpg")
        flag = "" if min(lo, hi) >= 4.5 else "   <-- FAILS"
        print(f"  {slot:<9} light {lo:.1f}:1   dark {hi:.1f}:1{flag}")
