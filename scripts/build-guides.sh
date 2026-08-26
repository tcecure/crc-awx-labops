#!/bin/bash
# Build student-facing DOCX + PDF from the completion guide Markdown.
#
# Tables: pandoc's docx writer emits <w:tblW w:type="pct" w:w="0.0"/> with no
# tblGrid for pipe tables, and LibreOffice/Word then collapse every column after
# the first, so the width is rewritten to full page and layout set to autofit.
# PDF: rendered from HTML via weasyprint (print.css keeps code blocks, the OU
# tree and tables from splitting across pages) instead of a DOCX conversion.
# Usage: scripts/build-guides.sh AC IA MP PE SC SI
# Requires pandoc and weasyprint (pip install weasyprint).
set -euo pipefail
DOCS="$(cd "$(dirname "$0")/../docs" && pwd)"
OUT="${GUIDE_OUT_DIR:-$DOCS}"
CSS="$DOCS/print.css"
mkdir -p "$OUT"

fix_docx_tables() {
  python3 - "$1" <<'PY'
import os, shutil, sys, zipfile
path = sys.argv[1]
src = path + ".tmp"
shutil.move(path, src)
zin = zipfile.ZipFile(src)
with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as zout:
    for item in zin.infolist():
        data = zin.read(item.filename)
        if item.filename == "word/document.xml":
            xml = data.decode()
            xml = xml.replace('<w:tblW w:type="pct" w:w="0.0" />',
                              '<w:tblW w:type="pct" w:w="5000" />'
                              '<w:tblLayout w:type="autofit" />')
            data = xml.encode()
        zout.writestr(item, data)
zin.close()
os.remove(src)
PY
}

for f in "$@"; do
  src="$DOCS/$f-Lab-Completion-Guide.md"
  base="$f-Lab-Completion-Guide"
  pandoc "$src" -f gfm -t docx --toc --toc-depth=2 -o "$OUT/$base.docx"
  fix_docx_tables "$OUT/$base.docx"
  title="$(sed -n 's/^# //p' "$src" | head -1)"
  pandoc "$src" -f gfm -t html5 --standalone --toc --toc-depth=2 \
    --metadata title="$title" -c "$CSS" -o "$OUT/$base.html"
  weasyprint "$OUT/$base.html" "$OUT/$base.pdf"
  rm -f "$OUT/$base.html"
  [ "$OUT" = "$DOCS" ] || cp "$OUT/$base.docx" "$OUT/$base.pdf" "$DOCS/"
  echo "built $base"
done
