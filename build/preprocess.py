#!/usr/bin/env python3
"""Pre-process a README/guide Markdown file for the pandoc + Eisvogel PDF build.

  python3 build/preprocess.py <source.md> <output.processed.md> <version>

Steps:
  1. Strip shields.io badge images (they don't render well in print).
  2. Rewrite <img src="https://..."> tags to local files under build/images/,
     converting them to pandoc image syntax and honouring an explicit width:
       - width="NN%"  -> { width=NN% }   (used for smaller inline examples)
       - width="800" / no width -> { width=100% }  (full-width featured images)
     Images whose local file is missing or not a valid image (e.g. a 404 page
     saved as .jpg) are dropped so one dead link can't crash the whole build.
  3. Swap the GitHub README UTM tag for a PDF/ebook UTM so PDF clicks track
     separately from README clicks.
"""
import re
import sys
import os

IMAGES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "images")
_MAGIC = (b"\xff\xd8\xff", b"\x89PNG\r\n\x1a\n", b"GIF87a", b"GIF89a")


def _valid_image(path):
    try:
        if os.path.getsize(path) < 256:
            return False
        with open(path, "rb") as f:
            head = f.read(16)
    except OSError:
        return False
    if head.startswith(_MAGIC):
        return True
    # WEBP: "RIFF" .... "WEBP"
    return head[:4] == b"RIFF" and head[8:12] == b"WEBP"


def main():
    src, out, version = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(src, encoding="utf-8") as f:
        text = f.read()

    # 1. strip shields.io badge lines (markdown image badges)
    text = re.sub(r'^!\[[^\]]*\]\(https://img\.shields\.io[^)]*\)\s*$', '',
                  text, flags=re.MULTILINE)

    # 2. <img ...> -> local pandoc image with width (drop if file invalid/missing)
    def img_repl(m):
        tag = m.group(0)
        src_m = re.search(r'src="([^"]+)"', tag)
        if not src_m:
            return tag
        url = src_m.group(1)
        if not url.startswith("http"):
            return tag  # already local
        base = os.path.basename(url.split("?")[0])
        if not _valid_image(os.path.join(IMAGES_DIR, base)):
            print("    !! skipping missing/invalid image: %s" % base)
            return ""
        alt_m = re.search(r'alt="([^"]*)"', tag)
        alt = alt_m.group(1) if alt_m else ""
        w_m = re.search(r'width="([^"]+)"', tag)
        width = w_m.group(1).strip() if w_m else ""
        attr = "{ width=%s }" % width if width.endswith("%") else "{ width=100% }"
        return "![%s](build/images/%s)%s" % (alt, base, attr)

    text = re.sub(r'<img[^>]*>', img_repl, text)

    # 3. UTM swap (README/github -> ebook/pdf, versioned)
    text = text.replace(
        "utm_source=github&utm_medium=readme&utm_campaign=backlinks",
        "utm_source=ebook&utm_medium=pdf&utm_campaign=backlinks&utm_content=v%s" % version,
    )

    with open(out, "w", encoding="utf-8") as f:
        f.write(text)
    print("    pre-processed -> %s" % out)


if __name__ == "__main__":
    main()
