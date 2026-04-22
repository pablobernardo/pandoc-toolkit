#!/usr/bin/env python3
from __future__ import annotations

import re
import shutil
import sys
import urllib.error
import urllib.request
from pathlib import Path


NOTO_BASE_URL = "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/svg"
TWEMOJI_BASE_URL = "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/svg"


def fail(msg: str) -> None:
    print(f"⚠️ [prepare-emojis] {msg}")
    raise SystemExit(1)


def normalize_name(codepoints: list[int]) -> str:
    vs = {0xFE0E, 0xFE0F}
    return "-".join(f"{cp:x}" for cp in codepoints if cp not in vs)


def extract_emoji_names(text: str) -> set[str]:
    zwj = 0x200D
    vs = {0xFE0E, 0xFE0F}

    cps = [ord(ch) for ch in text]
    names: set[str] = set()
    i = 0
    n = len(cps)

    def is_regional(cp: int) -> bool:
        return 0x1F1E6 <= cp <= 0x1F1FF

    def is_tone(cp: int) -> bool:
        return 0x1F3FB <= cp <= 0x1F3FF

    def is_keycap_base(cp: int) -> bool:
        return cp == 0x0023 or cp == 0x002A or 0x0030 <= cp <= 0x0039

    def is_emojiish(cp: int) -> bool:
        return cp >= 0x1F000 or 0x2600 <= cp <= 0x27FF

    while i < n:
        cp = cps[i]

        if is_regional(cp):
            if i + 1 < n and is_regional(cps[i + 1]):
                names.add(f"{cp:x}-{cps[i + 1]:x}")
                i += 2
                continue
            i += 1
            continue

        if is_keycap_base(cp):
            j = i + 1
            seq = [cp]
            if j < n and cps[j] in vs:
                seq.append(cps[j])
                j += 1
            if j < n and cps[j] == 0x20E3:
                seq.append(0x20E3)
                names.add(normalize_name(seq))
                i = j + 1
                continue

        if is_emojiish(cp):
            seq = [cp]
            j = i + 1

            if j < n and is_tone(cps[j]):
                seq.append(cps[j])
                j += 1

            while j < n and cps[j] == zwj:
                seq.append(zwj)
                j += 1
                if j < n:
                    seq.append(cps[j])
                    j += 1
                    if j < n and is_tone(cps[j]):
                        seq.append(cps[j])
                        j += 1

            name = normalize_name(seq)
            if name:
                names.add(name)
            i = j
            continue

        i += 1

    names.update({"2610", "2611", "2612"})
    return names


def download(url: str, dest: Path) -> bool:
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            dest.write_bytes(r.read())
        return True
    except (urllib.error.URLError, TimeoutError):
        return False


def ensure_missing_svg(target_dir: Path) -> None:
    missing = target_dir / "_missing.svg"
    if missing.exists():
        return
    missing.write_text(
        """<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"16\" height=\"16\" viewBox=\"0 0 16 16\">\n"
        "  <rect width=\"16\" height=\"16\" rx=\"2\" ry=\"2\" fill=\"#ddd\" stroke=\"#999\"/>\n"
        "  <text x=\"8\" y=\"11\" font-size=\"10\" text-anchor=\"middle\" fill=\"#666\">?</text>\n"
        "</svg>\n""",
        encoding="utf-8",
    )


def main() -> None:
    if len(sys.argv) < 4:
        fail("Uso: prepare-emojis.py <merged.md> <target_dir> <bundled_emoji_dir>")

    md_file = Path(sys.argv[1])
    target_dir = Path(sys.argv[2])
    bundled_dir = Path(sys.argv[3])

    if not md_file.exists():
        fail(f"No existe markdown combinado: {md_file}")

    target_dir.mkdir(parents=True, exist_ok=True)

    if bundled_dir.exists():
        for svg in bundled_dir.glob("*.svg"):
            shutil.copy2(svg, target_dir / svg.name)

    ensure_missing_svg(target_dir)

    text = md_file.read_text(encoding="utf-8", errors="ignore")
    names = sorted(extract_emoji_names(text))

    for name in names:
        tw_path = target_dir / f"{name}.svg"
        underscored = name.replace("-", "_").lower()
        noto_name = f"emoji_u{underscored}.svg"
        noto_path = target_dir / noto_name

        if tw_path.exists() or noto_path.exists():
            continue

        remap = "2714" if name == "2713" else underscored
        noto_url = f"{NOTO_BASE_URL}/emoji_u{remap}.svg"
        if download(noto_url, noto_path):
            if not tw_path.exists():
                shutil.copy2(noto_path, tw_path)
            continue

        tw_url = f"{TWEMOJI_BASE_URL}/{name}.svg"
        download(tw_url, tw_path)


if __name__ == "__main__":
    main()
