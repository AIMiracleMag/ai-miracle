#!/usr/bin/env bash
# Build a PDF from a Markdown source using pandoc + the Eisvogel template.
#
# Usage: build/build-pdf.sh [SOURCE_MD] [METADATA_YML] [OUTPUT_PDF]
#   defaults: README.md  build/metadata.yml  ai-miracle-collection.pdf
#
# Add a new document by dropping a new .md at the repo root, a matching
# build/metadata-<name>.yml, and one more invocation in the workflow.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$REPO_ROOT/build"
IMAGES_DIR="$BUILD_DIR/images"

SOURCE_MD="${1:-README.md}"
METADATA="${2:-build/metadata.yml}"
OUTPUT_FILENAME="${3:-ai-miracle-collection.pdf}"
PDF_VERSION="${PDF_VERSION:-$(date +%Y-%m)}"

BASE="$(basename "$SOURCE_MD" .md)"
WORK_MD="$BUILD_DIR/${BASE}.processed.md"
OUTPUT_PDF="$REPO_ROOT/$OUTPUT_FILENAME"

mkdir -p "$IMAGES_DIR"

echo "  > [1/4] Downloading images referenced in $SOURCE_MD ..."
grep -oE 'src="[^"]+"' "$REPO_ROOT/$SOURCE_MD" | sed -E 's/src="([^"]+)"/\1/' | sort -u | while read -r url; do
    case "$url" in http*) ;; *) continue ;; esac
    filename="$(basename "${url%%\?*}")"
    target="$IMAGES_DIR/$filename"
    if [ ! -f "$target" ]; then
        echo "    fetching $filename"
        curl -sL --max-time 30 "$url" -o "$target" || echo "    !! failed: $url"
    fi
done

echo "  > [2/4] Pre-processing $SOURCE_MD (local images, width, UTM swap, strip badges)..."
python3 "$BUILD_DIR/preprocess.py" "$REPO_ROOT/$SOURCE_MD" "$WORK_MD" "$PDF_VERSION"

echo "  > [3/4] Building $OUTPUT_FILENAME with pandoc + Eisvogel (via Docker)..."
# MSYS_NO_PATHCONV prevents Git Bash on Windows from mangling /data into C:/Program Files/Git/data
MSYS_NO_PATHCONV=1 docker run --rm \
    -v "$REPO_ROOT":/data \
    -w /data \
    pandoc/extra:latest \
    "build/${BASE}.processed.md" \
        --from markdown \
        --pdf-engine xelatex \
        --template build/eisvogel.latex \
        --syntax-highlighting idiomatic \
        --toc \
        --toc-depth 2 \
        --metadata-file "$METADATA" \
        --resource-path .:build \
        --output "$OUTPUT_FILENAME"

echo "  > [4/4] Done. Output: $OUTPUT_PDF"
ls -lh "$OUTPUT_PDF"
