"""Builds fonts/lxgw-wenkai-subset.ttf (handwriting font for the diary).

Source: LXGW WenKai (霞鹜文楷, SIL OFL 1.1) regular webfont subsets from the
npm package `lxgw-wenkai-webfont`. Only the characters used by the project
(all .gd / .tres text + an extra list) are kept so the file stays small.

Usage: python3 tools/fonts/build_hand_font.py <path to extracted npm package>
   or: python3 tools/fonts/build_hand_font.py <LXGWWenKai-Regular.ttf>
       (the v1.250 TTF from github.com/lxgw/LxgwWenKai, fonts/TTF/)
Re-run whenever new diary text/item names are added.
"""
import glob
import os
import sys

from fontTools import subset
from fontTools.merge import Merger
from fontTools.ttLib import TTFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
EXTRA = "0123456789０１２３４５６７８９年月日今天搜到了一些和、。，！？…—“”：；（）按任意键继续甚至还找妹也很开心说没关系什么都没有一无所获"


def project_chars():
    chars = set(EXTRA)
    for pattern in ("scripts/**/*.gd", "resources/**/*.tres", "scenes/**/*.tscn"):
        for p in glob.glob(os.path.join(ROOT, pattern), recursive=True):
            with open(p, encoding="utf-8") as f:
                chars.update(f.read())
    chars.update(chr(c) for c in range(0x20, 0x7F))
    return {ch for ch in chars if ch.isprintable()}


def main(pkg):
    chars = project_chars()
    text = "".join(sorted(chars))
    parts = []
    tmp = os.path.join(ROOT, ".font_tmp")
    os.makedirs(tmp, exist_ok=True)
    if pkg.lower().endswith((".ttf", ".otf")):
        sources = [pkg]
    else:
        sources = sorted(glob.glob(os.path.join(pkg, "files", "lxgwwenkai-regular-subset-*.woff2")))
    for i, src in enumerate(sources):
        font = TTFont(src)
        cmap = font.getBestCmap()
        need = [ch for ch in text if ord(ch) in cmap]
        if not need:
            continue
        opts = subset.Options()
        opts.flavor = None
        opts.layout_features = ["*"]
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        sub = subset.Subsetter(opts)
        sub.populate(text="".join(need))
        sub.subset(font)
        font.flavor = None
        out = os.path.join(tmp, f"p{i}.ttf")
        font.save(out)
        parts.append(out)
    merged = Merger().merge(parts) if len(parts) > 1 else TTFont(parts[0])
    dst = os.path.join(ROOT, "fonts", "lxgw-wenkai-subset.ttf")
    merged.save(dst)
    for p in parts:
        os.remove(p)
    os.rmdir(tmp)
    got = set(chr(c) for c in TTFont(dst).getBestCmap())
    missing = sorted(ch for ch in chars if ch not in got and ord(ch) > 0x2000)
    print("saved", dst, os.path.getsize(dst), "bytes; glyph chars:", len(got), "missing:", "".join(missing[:80]))


if __name__ == "__main__":
    main(sys.argv[1])
