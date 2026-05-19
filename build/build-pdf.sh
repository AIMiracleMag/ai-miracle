#!/usr/bin/env bash
# Build PDF from README.md using pandoc + Eisvogel template.
# Run from repo root: ./build/build-pdf.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
IMAGES_DIR="$BUILD_DIR/images"
WORK_README="$BUILD_DIR/README.processed.md"
PDF_VERSION="${PDF_VERSION:-$(date +%Y-%m)}"
OUTPUT_FILENAME="ai-miracle-collection.pdf"
OUTPUT_PDF="$REPO_ROOT/$OUTPUT_FILENAME"

mkdir -p "$IMAGES_DIR"

echo "==> [1/4] Downloading images referenced in README..."
grep -oE 'src="[^"]+"' "$REPO_ROOT/README.md" | sed -E 's/src="([^"]+)"/\1/' | sort -u | while read -r url; do
    filename=$(basename "$url")
    target="$IMAGES_DIR/$filename"
    if [ ! -f "$target" ]; then
        echo "    fetching $filename"
        curl -sL --max-time 30 "$url" -o "$target" || echo "    !! failed: $url"
    fi
done

echo "==> [2/4] Pre-processing README (rewrite remote img URLs to local paths, strip badges, swap UTMs)..."
# - Strip shields.io badge lines (don't render well in PDF)
# - Rewrite remote image URLs to local files
# - Rewrite <img> HTML tags to markdown image syntax with width
# - Swap UTM source/medium so PDF clicks track separately from GitHub README clicks
PDF_UTMS="utm_source=ebook\&utm_medium=pdf\&utm_campaign=backlinks\&utm_content=v${PDF_VERSION}"
sed -E '/!\[(Website|Collections)\]\(https:\/\/img\.shields\.io/d' "$REPO_ROOT/README.md" | \
    sed -E 's|src="https://www\.aimiracle\.ai/wp-content/uploads/[0-9]+/[0-9]+/([^"]+)"|src="build/images/\1"|g' | \
    sed -E 's|<img[^>]+src="(build/images/[^"]+)"[^>]*alt="([^"]*)"[^>]*>|![\2](\1){ width=100% }|g' | \
    sed -E 's|<img[^>]+src="(build/images/[^"]+)"[^>]*>|![](\1){ width=100% }|g' | \
    sed -E "s|utm_source=github\&utm_medium=readme\&utm_campaign=backlinks|${PDF_UTMS}|g" \
    > "$WORK_README"

echo "==> [3/4] Building PDF with pandoc + Eisvogel (via Docker)..."
# MSYS_NO_PATHCONV prevents Git Bash on Windows from mangling /data into C:/Program Files/Git/data
MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$REPO_ROOT":/data \
    -w /data \
    pandoc/extra:latest \
    build/README.processed.md \
        --from markdown \
        --pdf-engine=xelatex \
        --template=build/eisvogel.latex \
        --syntax-highlighting=idiomatic \
        --toc \
        --toc-depth=2 \
        --metadata-file=build/metadata.yml \
        --resource-path=.:build \
        --output=${OUTPUT_FILENAME}

echo "==> [4/4] Done. Output: $OUTPUT_PDF"
ls -lh "$OUTPUT_PDF"
