#!/usr/bin/env python3
"""Pre-process a README/guide Markdown file for the pandoc + Eisvogel PDF build.

  python3 build/preprocess.py <source.md> <output.processed.md> <version>

Steps:
  1. Strip shields.io badge images (they don't render well in print).
  2. Rewrite <img src="https://..."> tags to local files under build/images/,
     converting them to pandoc image syntax and honouring an explicit width:
       - width="NN%"  -> { width=NN% }   (used for smaller inline examples)
       - width="800" / no width -> { width=100% }  (full-width featured images)
  3. Swap the GitHub README UTM tag for a PDF/ebook UTM so PDF clicks track
     separately from README clicks.
"""
import re
import sys
import os

def main():
    src, out, version = sys.argv[1], sys.argv[2], sys.argv[3]
    with open(src, encoding="utf-8") as f:
        text = f.read()

    # 1. strip shields.io badge lines (markdown image badges)
    text = re.sub(r'^!\[[^\]]*\]\(https://img\.shields\.io[^)]*\)\s*$', '',
                  text, flags=re.MULTILINE)

    # 2. <img ...> -> local pandoc image with width
    def img_repl(m):
        tag = m.group(0)
        src_m = re.search(r'src="([^"]+)"', tag)
        if not src_m:
            return tag
        url = src_m.group(1)
        if not url.startswith("http"):
            return tag  # already local
        base = os.path.basename(url.split("?")[0])
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
