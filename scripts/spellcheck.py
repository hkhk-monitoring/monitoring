#!/usr/bin/env python3
"""Eesti keele õigekirjakontroll Vabamorfiga (EstNLTK kaudu).

Kasutus:
    pip install estnltk        # Python 3.10-3.12
    python scripts/spellcheck.py [failid...] [--uued] [--sonastik .sonastik.txt]

Kontrollib ainult proosat: frontmatter, koodiplokid, `inline kood`, lingid,
URL-id ja HTML-märgendid eemaldatakse enne kontrolli.
Ladina tähtedega sõnad, mida Vabamorf ei tunne (tihti ingliskeelsed terminid),
lisa faili .sonastik.txt (üks sõna real). --uued prindib kõik tundmatud
sõnad korraga, et neid sinna kopeerida.

Väljumiskood on alati 0 (ainult hoiatused), välja arvatud --strict.
"""
from __future__ import annotations

import argparse
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

try:
    from estnltk.vabamorf.morf import Vabamorf
except ImportError:
    sys.exit("EstNLTK puudub: pip install estnltk (Python 3.10-3.12)")


SÕNA_RE = re.compile(r"[A-Za-zÕÄÖÜŠŽõäöüšž]+(?:-[A-Za-zÕÄÖÜŠŽõäöüšž]+)*")


def puhasta(tekst: str) -> list[tuple[int, str]]:
    """Tagastab (rea_nr, proosarida) paarid."""
    lines = tekst.splitlines()
    i = 0
    if lines and lines[0].strip() == "---":
        for j in range(1, len(lines)):
            if lines[j].strip() == "---":
                i = j + 1
                break
    tulem = []
    koodis = False
    for n in range(i, len(lines)):
        l = lines[n]
        if re.match(r"^\s*(`{3,}|~{3,})", l):
            koodis = not koodis
            continue
        if koodis:
            continue
        l = re.sub(r"`[^`]*`", " ", l)
        l = re.sub(r"!\[[^\]]*\]\([^)]*\)", " ", l)
        l = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", l)
        l = re.sub(r"https?://\S+", " ", l)
        l = re.sub(r"<[^>]+>", " ", l)
        l = re.sub(r"\[\^[^\]]+\]:?", " ", l)
        l = re.sub(r"^(!!!|\?\?\?\+?)\s+\w+", " ", l)
        tulem.append((n + 1, l))
    return tulem


def kontrolli(sõnad: list[str]) -> dict[str, list[str]]:
    """Tagastab {vigane_sõna: soovitused}."""
    vm = Vabamorf.instance()
    vead = {}
    unikaalsed = sorted(set(sõnad))
    for algus in range(0, len(unikaalsed), 500):
        tükk = unikaalsed[algus:algus + 500]
        for r in vm.spellcheck(tükk, suggestions=True):
            if not r["spelling"]:
                vead[r["text"]] = r.get("suggestions", [])[:3]
    return vead


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("failid", nargs="*")
    ap.add_argument("--docs", default="docs")
    ap.add_argument("--sonastik", default=".sonastik.txt")
    ap.add_argument("--uued", action="store_true", help="prindi ainult tundmatute sõnade nimekiri")
    ap.add_argument("--strict", action="store_true", help="väljumiskood 1, kui leidub vigu")
    a = ap.parse_args()

    lubatud = set()
    sp = Path(a.sonastik)
    if sp.exists():
        lubatud = {w.strip().lower() for w in sp.read_text(encoding="utf-8").splitlines()
                   if w.strip() and not w.startswith("#")}

    failid = [Path(f) for f in a.failid if f.endswith(".md")] or sorted(Path(a.docs).rglob("*.md"))

    asukohad: dict[str, list[tuple[str, int]]] = defaultdict(list)
    for f in failid:
        for nr, rida in puhasta(f.read_text(encoding="utf-8")):
            for m in SÕNA_RE.finditer(rida):
                w = m.group(0)
                if len(w) < 3 or w.isupper() or w.lower() in lubatud:
                    continue
                # CamelCase (OpenTofu, GitHub) jäetakse vahele
                if re.search(r"[a-zõäöü][A-ZÕÄÖÜ]", w):
                    continue
                for osa in w.split("-"):
                    if len(osa) >= 3 and osa.lower() not in lubatud:
                        asukohad[osa].append((f.as_posix(), nr))

    vead = kontrolli(list(asukohad))

    if a.uued:
        for w in sorted({w.lower() for w in vead}):
            print(w)
        return 0

    gha = os.environ.get("GITHUB_ACTIONS") == "true"
    for w, soov in sorted(vead.items(), key=lambda kv: asukohad[kv[0]][0]):
        f, nr = asukohad[w][0]
        mitu = f" (+{len(asukohad[w]) - 1} kohta)" if len(asukohad[w]) > 1 else ""
        sõnum = f"tundmatu sõna «{w}»{mitu}" + (f", kas mõtlesid: {', '.join(soov)}?" if soov else "")
        if gha:
            print(f"::warning file={f},line={nr},title=õigekiri::{sõnum}")
        else:
            print(f"{f}:{nr}: {sõnum}")
    print(f"\n{len(failid)} faili, {len(vead)} tundmatut sõna", file=sys.stderr)
    return 1 if vead and a.strict else 0


if __name__ == "__main__":
    sys.exit(main())
