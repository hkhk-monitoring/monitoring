#!/usr/bin/env python3
"""Kursusematerjalide stiilikontroll.

Kasutus:
    python scripts/lint.py [failid...] [--config stiil.yml] [--json] [--warn-only]

Ilma failideta kontrollib kõiki docs_dir all olevaid .md faile.
Väljumiskood 1, kui leidub vigu (hoiatused ei mõjuta), välja arvatud --warn-only.
GitHub Actionsis prindib vead annotatsioonidena, et need paistaksid PR-is rea juures.
"""
from __future__ import annotations

import argparse
import fnmatch
import json
import os
import re
import sys
from dataclasses import dataclass, asdict
from pathlib import Path

import yaml


@dataclass
class Leid:
    fail: str
    rida: int
    tase: str  # "viga" | "hoiatus"
    reegel: str
    sõnum: str


# ---------- abifunktsioonid ----------

class _IgnoreTagsLoader(yaml.SafeLoader):
    """Loeb mkdocs.yml-i, ignoreerides !!python/name jms silte."""


def _ignore(loader, suffix, node):
    return None


_IgnoreTagsLoader.add_multi_constructor("!", _ignore)
_IgnoreTagsLoader.add_multi_constructor("tag:yaml.org,2002:python/", _ignore)


def matchib(path: str, globid: list[str]) -> bool:
    p = path.replace(os.sep, "/")
    for g in globid:
        if fnmatch.fnmatch(p, g) or fnmatch.fnmatch(p, g.removeprefix("**/")):
            return True
    return False


def jaga_frontmatter(lines: list[str]):
    """Tagastab (frontmatter_dict | None, sisu_algus_rida_0põhine, viga | None)."""
    if not lines or lines[0].strip() != "---":
        return None, 0, "frontmatter puudub"
    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            try:
                data = yaml.safe_load("".join(lines[1:i])) or {}
            except yaml.YAMLError as e:
                return None, i + 1, f"frontmatter ei ole korrektne YAML: {e}"
            return data, i + 1, None
    return None, 0, "frontmatter ei sulgu (---)"


FENCE_RE = re.compile(r"^(\s*)(`{3,}|~{3,})(.*)$")


def koodiread(lines: list[str], start: int):
    """Hulk rea-indekseid, mis on koodiplokis (k.a piirdejooned), ja avamisread."""
    sees = set()
    avamised = []  # (rea_idx, info_string)
    i = start
    open_fence = None
    for i in range(start, len(lines)):
        m = FENCE_RE.match(lines[i])
        if open_fence is None:
            if m:
                open_fence = m.group(2)
                avamised.append((i, m.group(3).strip()))
                sees.add(i)
        else:
            sees.add(i)
            if m and m.group(2).startswith(open_fence[0]) and len(m.group(2)) >= len(open_fence) and not m.group(3).strip():
                open_fence = None
    return sees, avamised


# ---------- kontrollid ----------

IMG_RE = re.compile(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)")
HTML_IMG_RE = re.compile(r"<img\b[^>]*>", re.I)
CAPTION_JOONIS_RE = re.compile(r"<figcaption>\s*Joonis\s+([\w]+\.\d+)\.", re.I)
FIGCAPTION_RE = re.compile(r"<figcaption>(.*?)(</figcaption>|$)", re.I)
TABEL_CAP_RE = re.compile(r"^\*Tabel\s+([\w]+\.\d+|\d+)\.")
TABEL_BLOCKQUOTE_RE = re.compile(r"^>\s*\**Tabel\s+\d", re.I)
FOOT_DEF_RE = re.compile(r"^\[\^([^\]]+)\]:")
FOOT_REF_RE = re.compile(r"\[\^([^\]]+)\](?!:)")
H1_RE = re.compile(r"^# \S")


def kontrolli_faili(path: Path, rel: str, cfg: dict, repo: Path) -> list[Leid]:
    leiud: list[Leid] = []

    def lisa(rida, tase, reegel, sõnum):
        leiud.append(Leid(rel, rida, tase, reegel, sõnum))

    tekst = path.read_text(encoding="utf-8")
    lines = tekst.splitlines(keepends=True)

    # frontmatter + sildid
    fm, sisu_algus, fm_viga = jaga_frontmatter(lines)
    if fm_viga:
        lisa(1, "viga", "frontmatter", fm_viga)
    else:
        tags = fm.get("tags") or []
        if not isinstance(tags, list) or not tags:
            lisa(1, "viga", "sildid", "tags: puudub või on tühi")
        else:
            sildid = cfg.get("sildid", {})
            lubatud = {t for grupp in sildid.values() for t in grupp}
            for t in tags:
                if t not in lubatud:
                    lisa(1, "viga", "sildid", f"silt '{t}' ei ole stiil.yml lubatud nimekirjas")
            for grupp in ("tüüp", "teema"):
                if grupp in sildid and not set(tags) & set(sildid[grupp]):
                    lisa(1, "viga", "sildid", f"puudub '{grupp}' silt ({', '.join(sildid[grupp][:4])}...)")

    koodis, avamised = koodiread(lines, sisu_algus)

    # koodiplokkide keel
    for idx, info in avamised:
        if not info:
            lisa(idx + 1, "viga", "kood", "koodiplokil puudub keel (```bash, ```text ...)")

    # failitüübi nõuded
    for nimi, ft in (cfg.get("failitüübid") or {}).items():
        if not matchib(rel, ft.get("globid", [])):
            continue
        prose = [l for i, l in enumerate(lines) if i >= sisu_algus and i not in koodis]
        for muster, kirjeldus in ft.get("nõutud", []):
            if not any(re.search(muster, l) for l in prose):
                lisa(1, "viga", f"struktuur:{nimi}", f"puudub {kirjeldus}")
        for muster, kirjeldus in ft.get("keelatud", []):
            for i, l in enumerate(lines):
                if i >= sisu_algus and i not in koodis and re.search(muster, l):
                    lisa(i + 1, "viga", f"struktuur:{nimi}", kirjeldus)
                    break

    h1 = []
    joonised: dict[str, int] = {}
    tabelid: dict[str, int] = {}
    foot_defs: dict[str, int] = {}
    foot_refs: dict[str, int] = {}
    figure_sügavus = 0
    pildinimi_re = re.compile(cfg.get("pildinimi", ".*"))
    sufiksid = [re.compile(s) for s in cfg.get("keelatud_pildisufiksid", [])]
    fraasid = [(re.compile(m, re.I | re.M), k) for m, k in cfg.get("keelatud_fraasid", [])]
    hoiatused = [(re.compile(m, re.I), k) for m, k in cfg.get("hoiatused", [])]

    for i in range(sisu_algus, len(lines)):
        l = lines[i]
        nr = i + 1

        # fraasid kontrollitakse ka koodis (nt terraform apply)
        for rx, k in fraasid:
            if rx.search(l):
                lisa(nr, "viga", "keelatud", f"{k}: «{rx.search(l).group(0).strip()}»")
        if i in koodis:
            continue
        for rx, k in hoiatused:
            if rx.search(l):
                lisa(nr, "hoiatus", "stiil", k)

        if H1_RE.match(l):
            h1.append(nr)

        if "<figure" in l:
            figure_sügavus += 1
        if "</figure>" in l:
            figure_sügavus = max(0, figure_sügavus - 1)

        # pildid
        for m in IMG_RE.finditer(l):
            alt, src = m.group(1).strip(), m.group(2)
            if not alt:
                lisa(nr, "viga", "pilt", f"alt-tekst puudub: {src}")
            elif alt.lower() in {"pilt", "joonis", "diagramm", "image", "screenshot", "ekraanipilt"}:
                lisa(nr, "hoiatus", "pilt", f"alt-tekst on liiga üldine: '{alt}'")
            if figure_sügavus == 0:
                lisa(nr, "viga", "pilt", 'pilt peab olema <figure markdown="span"> sees')
            if src.startswith(("http://", "https://")):
                lisa(nr, "hoiatus", "pilt", "väline pilt, lae alla assets/ kausta")
                continue
            fail = Path(src.split("#")[0]).name
            if not pildinimi_re.match(fail):
                lisa(nr, "viga", "pildinimi", f"'{fail}' ei vasta nimekonventsioonile (t02_teema.png)")
            for s in sufiksid:
                if s.search(fail):
                    lisa(nr, "viga", "pildinimi", f"'{fail}' sisaldab versioonisufiksit")
            sihtmärk = (path.parent / src.split("#")[0]).resolve()
            if not sihtmärk.exists():
                lisa(nr, "viga", "pilt", f"pildifaili ei leitud: {src}")
            elif sihtmärk.stat().st_size > cfg.get("pildi_max_kb", 300) * 1024:
                kb = sihtmärk.stat().st_size // 1024
                lisa(nr, "hoiatus", "pildi suurus", f"'{fail}' on {kb} kB (soovitus ~150 kB, piir {cfg.get('pildi_max_kb', 300)} kB)")
        if HTML_IMG_RE.search(l) and 'alt="' not in l.lower():
            lisa(nr, "viga", "pilt", "<img> ilma alt-atribuudita")

        # figcaption
        fc = FIGCAPTION_RE.search(l)
        if fc:
            cm = CAPTION_JOONIS_RE.search(l)
            if not cm:
                lisa(nr, "viga", "joonis", "figcaption peab algama 'Joonis N.n.'")
            else:
                nrm = cm.group(1)
                if nrm in joonised:
                    lisa(nr, "viga", "joonis", f"Joonis {nrm} on juba real {joonised[nrm]}")
                joonised[nrm] = nr

        # tabelid
        if TABEL_BLOCKQUOTE_RE.match(l):
            lisa(nr, "viga", "tabel", "tabeli pealkiri blockquote'is, pane tabeli alla: *Tabel N.n. ...*")
        tm = TABEL_CAP_RE.match(l.strip())
        if tm:
            nrm = tm.group(1)
            if nrm in tabelid:
                lisa(nr, "viga", "tabel", f"Tabel {nrm} on juba real {tabelid[nrm]}")
            tabelid[nrm] = nr
            # eelmine mittetühi rida peab olema tabelirida
            j = i - 1
            while j >= sisu_algus and not lines[j].strip():
                j -= 1
            if j < sisu_algus or not lines[j].lstrip().startswith("|"):
                lisa(nr, "viga", "tabel", "tabeli pealkiri peab olema vahetult tabeli all")

        # joonealused
        dm = FOOT_DEF_RE.match(l)
        if dm:
            foot_defs.setdefault(dm.group(1), nr)
        else:
            for rm in FOOT_REF_RE.finditer(re.sub(r"`[^`]*`", "", l)):
                foot_refs.setdefault(rm.group(1), nr)

    # mermaid väljaspool figure
    for idx, info in avamised:
        if info.startswith("mermaid"):
            enne = "".join(lines[max(sisu_algus, idx - 3):idx])
            if "<figure" not in enne:
                lisa(idx + 1, "viga", "joonis", 'mermaid peab olema <figure markdown="span"> sees')

    if len(h1) == 0:
        lisa(1, "viga", "pealkiri", "H1 pealkiri (# ...) puudub")
    elif len(h1) > 1:
        lisa(h1[1], "viga", "pealkiri", f"mitu H1 pealkirja (read {', '.join(map(str, h1))})")

    for fid, nr in foot_refs.items():
        if fid.isdigit():
            lisa(nr, "viga", "viide", f"[^{fid}] - kasuta kirjeldavat ID-d (nt [^rfc791])")
        if fid not in foot_defs:
            lisa(nr, "viga", "viide", f"[^{fid}] definitsioon puudub")
    for fid, nr in foot_defs.items():
        if fid not in foot_refs:
            lisa(nr, "hoiatus", "viide", f"[^{fid}] definitsiooni ei kasutata tekstis")

    return leiud


def nav_failid(repo: Path) -> set[str] | None:
    mk = repo / "mkdocs.yml"
    if not mk.exists():
        return None
    data = yaml.load(mk.read_text(encoding="utf-8"), Loader=_IgnoreTagsLoader) or {}
    nav = data.get("nav")
    if not nav:
        return None
    tulem: set[str] = set()

    def käi(x):
        if isinstance(x, str):
            if x.endswith(".md"):
                tulem.add(x)
        elif isinstance(x, list):
            for y in x:
                käi(y)
        elif isinstance(x, dict):
            for y in x.values():
                käi(y)

    käi(nav)
    return tulem


# ---------- põhiprogramm ----------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("failid", nargs="*")
    ap.add_argument("--config", default="stiil.yml")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--warn-only", action="store_true")
    a = ap.parse_args()

    repo = Path.cwd()
    cfg = yaml.safe_load(Path(a.config).read_text(encoding="utf-8")) or {}
    docs = repo / cfg.get("docs_dir", "docs")
    välja = cfg.get("välja_jäetud", [])

    if a.failid:
        failid = [Path(f) for f in a.failid if f.endswith(".md")]
    else:
        failid = sorted(docs.rglob("*.md"))

    leiud: list[Leid] = []
    for f in failid:
        rel = f.resolve().relative_to(repo.resolve()).as_posix() if f.resolve().is_relative_to(repo.resolve()) else f.as_posix()
        if matchib(rel, välja):
            continue
        leiud += kontrolli_faili(f, rel, cfg, repo)

    # orvuks jäänud lehed (ainult täiskontrolli korral)
    if not a.failid:
        nav = nav_failid(repo)
        if nav is not None:
            for f in failid:
                r = f.relative_to(docs).as_posix()
                if r not in nav and not matchib(f.relative_to(repo).as_posix(), välja):
                    leiud.append(Leid(f.relative_to(repo).as_posix(), 1, "hoiatus", "nav", "fail ei ole mkdocs.yml nav all"))

    vead = [x for x in leiud if x.tase == "viga"]
    if a.json:
        print(json.dumps([asdict(x) for x in leiud], ensure_ascii=False, indent=2))
    else:
        gha = os.environ.get("GITHUB_ACTIONS") == "true"
        for x in sorted(leiud, key=lambda x: (x.fail, x.rida)):
            if gha:
                tüüp = "error" if x.tase == "viga" else "warning"
                print(f"::{tüüp} file={x.fail},line={x.rida},title={x.reegel}::{x.sõnum}")
            else:
                print(f"{x.fail}:{x.rida}: {x.tase.upper()} [{x.reegel}] {x.sõnum}")
        print(f"\n{len(failid)} faili, {len(vead)} viga, {len(leiud) - len(vead)} hoiatust", file=sys.stderr)

    return 1 if vead and not a.warn_only else 0


if __name__ == "__main__":
    sys.exit(main())
