#!/usr/bin/env python3
"""
Build flutter/assets/confessions.json — proof-text citation facts for the
Westminster Confession of Faith (1647) and the 1689 London Baptist
Confession, mapped to (globalChapter, verse) in the core canon of
flutter/assets/data.json.

Route (see README.md and LICENSE-EVIDENCE.md for the full record):
facts are DERIVED from the public-domain texts themselves, as published
by the documents' own publishers:

  * WCF  — Orthodox Presbyterian Church, "Confession of Faith with
    Scripture proofs" PDF (OPC standards page, opc.org/confessions.html;
    PDF: opc.org/documents/CFLayout.pdf). The OPC edition prints the
    proof texts as lettered footnotes (letters run a-z per chapter,
    skipping 'j', in the classical alphabet) with the full quoted text
    after each reference. Only the references are extracted; no
    confession text and no quoted Bible text is kept.
  * 1689 — Christian Classics Ethereal Library (CCEL) edition of
    "The 1677/89 London Baptist Confession of Faith ... with Scripture
    Proofs" (PDF: ccel.org/ccel/a/anonymous/bcf/cache/bcf.pdf). The
    CCEL edition prints the proofs as numbered footnotes (1-493,
    running through the whole confession) in the original old-style
    reference form ("2 Tim. 3. 15,16,17."). Only the references are
    extracted. The main body only (chapters I-XXXII) is parsed; the
    PDF's appendix and modern editorial matter are excluded.

Method in one paragraph per document:

WCF: pdftotext -layout; on each page, lines from the first indented
"<letter>. " line onward are footnote text; footnote blocks are kept
in stream order. In the body, superscript proof letters are printed
attached to punctuation (e.g. "salvation.b", "only,a"); candidate
markers are extracted with that pattern, carrying their (chapter,
section) context, and candidates are aligned to the footnote blocks
by a longest-common-subsequence alignment on the letter sequence
(letters must agree). Footnote blocks whose printed marker takes an
unusual form (attached directly to a word, e.g. "angelsf" in 3.3, or
standing alone after a comma) do not produce a candidate; such a
block is assigned to the section of its neighbouring matched markers
when both neighbours agree, otherwise to a small documented override
table below (each override was verified by eye against the printed
page). Any other unassignable block aborts the build.

1689: pdftotext -layout; footnote lines start at column 0 with the
footnote number and 2+ spaces (the 493 numbers validate as exactly
1..493 in order). Body superscript markers are bare numbers attached
to a word, standing after punctuation, or standing alone; candidates
are aligned to the footnote numbers by the same LCS alignment
(candidate values must equal footnote numbers). Unmatched footnotes
use the same neighbour rule / override policy as the WCF.

References are parsed with a book-alias table and expanded to
individual verses (lists and ranges expanded; cross-chapter ranges
expanded across chapters). A reference to a whole chapter (no verse
named, e.g. "Ps. 107.") is expanded to every verse of that chapter
and counted separately. "&c." (etcetera) continuations name no verse
and are dropped, counted separately. Every expanded verse is checked
against the verse counts in flutter/assets/data.json; out-of-range
verses are DROPPED (never clamped) and counted with examples.

Re-runnable: downloads the two PDFs into sources/ if absent
(sequential, identifying user agent), re-extracts, rebuilds, and ends
with an independent verification pass over the written JSON.
"""

import bisect
import json
import re
import subprocess
import sys
import time
import urllib.request
from collections import Counter
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]  # ~/workspace/woven-word
SOURCES = HERE / "sources"
CANON_PATH = ROOT / "flutter" / "assets" / "data.json"
OUT_PATH = ROOT / "flutter" / "assets" / "confessions.json"
UA = "woven-word-confessions-pipeline/1.0 (citation-facts derivation)"

WCF_PDF_URL = "https://opc.org/documents/CFLayout.pdf"
LBC_PDF_URL = "https://ccel.org/ccel/a/anonymous/bcf/cache/bcf.pdf"

# ---------------------------------------------------------------- canon

def load_canon():
    data = json.loads(CANON_PATH.read_text())
    books = data["books"]              # [{abbr, name, chapters, start}]
    chapters = data["chapters"]        # [{b, c, v}] in global order
    assert len(books) == 66 and len(chapters) == 1189
    verse_count = {}                   # (book_idx, chapter) -> verses
    for ch in chapters:
        verse_count[(ch["b"], ch["c"])] = ch["v"]
    return books, verse_count

BOOKS, VERSE_COUNT = load_canon()

# ------------------------------------------------------- book aliases
# alias text -> book index in the core canon (0 Genesis .. 65 Revelation)
ALIASES = {
    "genesis": 0, "gen": 0,
    "exodus": 1, "exod": 1, "ex": 1, "exo": 1,
    "leviticus": 2, "lev": 2, "levit": 2,
    "numbers": 3, "num": 3, "numb": 3,
    "deuteronomy": 4, "deut": 4,
    "joshua": 5, "josh": 5,
    "judges": 6, "judg": 6,
    "ruth": 7,
    "1 samuel": 8, "1 sam": 8, "i samuel": 8,
    "2 samuel": 9, "2 sam": 9, "ii samuel": 9,
    "1 kings": 10, "1 king": 10, "i kings": 10,
    "2 kings": 11, "ii kings": 11,
    "1 chronicles": 12, "1 chron": 12, "1 chr": 12, "i chronicles": 12,
    "1 chro": 12, "1 cro": 12,
    "2 chronicles": 13, "2 chron": 13, "2 chr": 13, "ii chronicles": 13,
    "2 chro": 13, "2 cro": 13,
    "ezra": 14,
    "nehemiah": 15, "neh": 15,
    "esther": 16, "esth": 16,
    "job": 17,
    "psalms": 18, "psalm": 18, "psal": 18, "psa": 18, "ps": 18,
    "proverbs": 19, "prov": 19, "pro": 19,
    "ecclesiastes": 20, "eccl": 20, "eccles": 20,
    "song of solomon": 21, "song of songs": 21, "canticles": 21, "cant": 21, "song": 21,
    "isaiah": 22, "isa": 22,
    "jeremiah": 23, "jer": 23,
    "lamentations": 24, "lam": 24,
    "ezekiel": 25, "ezek": 25, "eze": 25, "ezk": 25,
    "daniel": 26, "dan": 26,
    "hosea": 27, "hos": 27,
    "joel": 28,
    "amos": 29,
    "obadiah": 30, "obad": 30,
    "jonah": 31,
    "micah": 32, "mic": 32,
    "nahum": 33, "nah": 33,
    "habakkuk": 34, "hab": 34,
    "zephaniah": 35, "zeph": 35,
    "haggai": 36, "hag": 36,
    "zechariah": 37, "zech": 37,
    "malachi": 38, "mal": 38,
    "matthew": 39, "matt": 39, "mat": 39,
    "mark": 40, "mar": 40,
    "luke": 41, "luk": 41,
    "john": 42, "joh": 42,
    "acts": 43, "act": 43,
    "romans": 44, "rom": 44,
    "1 corinthians": 45, "1 cor": 45, "i corinthians": 45,
    "2 corinthians": 46, "2 cor": 46, "ii corinthians": 46,
    "galatians": 47, "gal": 47,
    "ephesians": 48, "eph": 48,
    "philippians": 49, "phil": 49, "phi": 49,
    "colossians": 50, "col": 50,
    "1 thessalonians": 51, "1 thess": 51, "1 thes": 51,
    "2 thessalonians": 52, "2 thess": 52, "2 thes": 52,
    "1 timothy": 53, "1 tim": 53,
    "2 timothy": 54, "2 tim": 54,
    "titus": 55, "tit": 55,
    "philemon": 56, "philem": 56, "phlm": 56,
    "hebrews": 57, "heb": 57, "hebr": 57,
    "james": 58, "jam": 58, "jas": 58,
    "1 peter": 59, "1 pet": 59,
    "2 peter": 60, "2 pet": 60,
    "1 john": 61, "1 joh": 61,
    "2 john": 62, "2 joh": 62,
    "3 john": 63, "3 joh": 63,
    "jude": 64, "jud": 64,
    "revelation": 65, "rev": 65, "revel": 65,
}
# longest alias first so "1 john" beats "john", etc.
ALIAS_RE = re.compile(
    r"\b(" + "|".join(re.escape(a) for a in sorted(ALIASES, key=len, reverse=True)) + r")\.?",
    re.IGNORECASE,
)

# ------------------------------------------------------------ fetching

def fetch(url, dest):
    if dest.exists() and dest.stat().st_size > 10000:
        print(f"  cached {dest.name} ({dest.stat().st_size} bytes)")
        return
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req) as r:
        dest.write_bytes(r.read())
    print(f"  downloaded {url} -> {dest.name} ({dest.stat().st_size} bytes)")
    time.sleep(1)

def pdf_text(pdf):
    txt = pdf.with_suffix(".txt")
    subprocess.run(["pdftotext", "-layout", str(pdf), str(txt)], check=True)
    return txt.read_text(errors="replace")

# ---------------------------------------------------- reference parsing
# A raw reference item is (book, ch1, v1, ch2, v2); a whole-chapter
# citation is (book, ch, None, ch, None).

def expand(item, stats):
    """Expand one raw item to validated (globalChapter, verse) pairs."""
    book, c1, v1, c2, v2 = item
    binfo = BOOKS[book]
    out = []
    if c1 < 1 or c1 > binfo["chapters"] or c2 < c1 or c2 > binfo["chapters"]:
        stats["dropped_items"] += 1
        if len(stats["drop_examples"]) < 25:
            stats["drop_examples"].append(f"chapter out of range: {item}")
        return out
    if v1 is None:  # whole chapter
        stats["whole_chapter"] += 1
        rng = [(c1, 1, VERSE_COUNT[(book, c1)])]
    else:
        rng = [(c, (v1 if c == c1 else 1), (v2 if c == c2 else VERSE_COUNT[(book, c)]))
               for c in range(c1, c2 + 1)]
    for c, a, b in rng:
        vc = VERSE_COUNT[(book, c)]
        for v in range(a, b + 1):
            if 1 <= v <= vc:
                out.append((binfo["start"] + c - 1, v))
            else:
                stats["dropped_verses"] += 1
                if len(stats["drop_examples"]) < 25:
                    stats["drop_examples"].append(
                        f"verse out of range: book {book} ch {c} v {v} (chapter has {vc})")
    return out

def parse_modern_refs(text, stats):
    """OPC style: 'Book C:V[, V | V-V | V-C:V]...' References sit inside
    footnote text that also quotes the verse; a book name only counts
    when a C:V tail parses immediately after it."""
    items = []
    pos_floor = 0
    for m in ALIAS_RE.finditer(text):
        if m.start() < pos_floor:
            continue
        book = ALIASES[m.group(1).lower()]
        rest = text[m.end():]
        head = re.match(r"\s*(\d+):(\d+)", rest)
        if not head:
            # Single-chapter books are cited by verse alone in the OPC
            # edition too ("Jude 6.", "2 John 9-11."): verse, optional
            # range, optional comma list — all of chapter 1.
            if BOOKS[book]["chapters"] == 1:
                vm = re.match(r"\s*(\d+)(?!\s*:)", rest)
                if vm:
                    v1 = int(vm.group(1))
                    v2 = v1
                    end = vm.end()
                    rm = re.match(r"\s*[-\u2013\u2014]\s*(\d+)", rest[end:])
                    if rm:
                        v2 = int(rm.group(1)); end += rm.end()
                    items.append((book, 1, v1, 1, v2))
                    while True:
                        cm = re.match(r"\s*,\s*(\d+)(?:\s*[-\u2013\u2014]\s*(\d+))?", rest[end:])
                        if not cm:
                            break
                        a = int(cm.group(1))
                        b = int(cm.group(2)) if cm.group(2) else a
                        items.append((book, 1, a, 1, b))
                        end += cm.end()
                    pos_floor = m.end() + end
            continue
        c1, v1 = int(head.group(1)), int(head.group(2))
        c2, v2 = c1, v1
        end = head.end()
        # range directly after the first verse: V-V or V-C:V
        rm = re.match(r"\s*[-\u2013\u2014]\s*(\d+)(?::(\d+))?", rest[end:])
        if rm:
            if rm.group(2):
                c2, v2 = int(rm.group(1)), int(rm.group(2))
            else:
                v2 = int(rm.group(1))
            end += rm.end()
        items.append((book, c1, v1, c2, v2))
        # comma-separated further verse items in the same chapter
        while True:
            cm = re.match(r"\s*,\s*(\d+)(?:\s*[-\u2013\u2014]\s*(\d+))?", rest[end:])
            if not cm:
                break
            a = int(cm.group(1))
            b = int(cm.group(2)) if cm.group(2) else a
            items.append((book, c1, a, c1, b))
            end += cm.end()
        pos_floor = m.end() + end
    return items

OLD_TOKEN_RE = re.compile(r"\d+|[-\u2013\u2014]|&c\.|&c|&|%|\bch\b\.?|\bv\b\.?|\band\b", re.IGNORECASE)

def parse_old_refs(text, stats):
    """1689 old style, refs only (no quoted text). After a book name:
    first number is the chapter, following numbers are verses of that
    chapter (separated by '.', ',' or space); '-' makes a verse range;
    'ch.' starts a new chapter group; 'v.' marks verses; '&c.' is an
    unnumbered continuation (dropped, counted); 'and' followed by a
    number too large to be a verse of the current chapter starts a
    new chapter group (e.g. 'Ps. 19. 7. and 119. 130.')."""
    # CCEL editorial notes in square brackets are modern matter, not
    # confession citations (two of them flag errors in the original
    # references and suggest modern substitutes — those substitutes are
    # NOT citations of the confession and must not be extracted).
    text, n_notes = re.subn(r"\[[^\]]*\]", " ", text)
    stats["editorial_notes_stripped"] = stats.get("editorial_notes_stripped", 0) + n_notes
    # Abbreviations that would be unsafe as global aliases:
    text = re.sub(r"\bIs\.", "Isa.", text)     # Isaiah
    text = re.sub(r"\bRo\.", "Rom.", text)     # Romans
    items = []
    matches = list(ALIAS_RE.finditer(text))
    for idx, m in enumerate(matches):
        book = ALIASES[m.group(1).lower()]
        seg_end = matches[idx + 1].start() if idx + 1 < len(matches) else len(text)
        seg = text[m.end():seg_end]
        tokens = OLD_TOKEN_RE.findall(seg)
        cur_ch = None
        mode = "chapter"          # chapter | verse
        group_open = False        # chapter started, no verse yet
        if BOOKS[book]["chapters"] == 1:
            # Single-chapter books (Jude, 2/3 John, Philemon, Obadiah)
            # are cited by verse alone: "Jud. 4." is Jude 1:4.
            cur_ch = 1
            mode = "verse"
        pending_range = False
        last = None               # index into items of current group's last verse item
        i = 0
        while i < len(tokens):
            tok = tokens[i]
            low = tok.lower().rstrip(".")
            if tok[0].isdigit():
                n = int(tok)
                if pending_range and last is not None:
                    b, c, a, _, _ = items[last]
                    items[last] = (b, c, a, c, n)
                    pending_range = False
                elif mode == "chapter" or cur_ch is None:
                    if group_open:
                        items.append((book, cur_ch, None, cur_ch, None))
                    cur_ch = n
                    mode = "verse"
                    last = None
                    group_open = True
                elif (i > 0 and tokens[i - 1].lower().rstrip(".") in ("and", "&", "%")
                      and cur_ch is not None and last is not None
                      and n > VERSE_COUNT.get((book, cur_ch), 0)):
                    # '& 51.' / 'and 119. 130': a number too large to be
                    # a verse of the current chapter, right after a
                    # conjunction, is a new chapter of the same book
                    # (with its own verses following, or none -> a
                    # whole-chapter citation).
                    if group_open:
                        items.append((book, cur_ch, None, cur_ch, None))
                    cur_ch = n
                    mode = "verse"
                    last = None
                    group_open = True
                else:
                    items.append((book, cur_ch, n, cur_ch, n))
                    last = len(items) - 1
                    group_open = False
            elif tok in ("-", "\u2013", "\u2014"):
                pending_range = True
            elif low == "ch":
                if group_open:
                    items.append((book, cur_ch, None, cur_ch, None))
                    group_open = False
                cur_ch = None
                mode = "chapter"
                last = None
            elif low == "v":
                mode = "verse"
            elif low in ("&c", "&c."):
                stats["etc_dropped"] += 1
            # '&', '%', 'and' alone: separators, no state change
            i += 1
        if group_open:
            # chapter named with no verse -> whole-chapter citation
            items.append((book, cur_ch, None, cur_ch, None))
    return items

# ------------------------------------------------------------- aligning

def lcs_align(cand_keys, block_keys):
    """Align two sequences by equality; returns (pairs, skipped_cands,
    skipped_blocks) with pairs as (cand_idx, block_idx)."""
    n, m = len(cand_keys), len(block_keys)
    dp = [[0] * (m + 1) for _ in range(n + 1)]
    for i in range(n - 1, -1, -1):
        for j in range(m - 1, -1, -1):
            best = dp[i + 1][j] if dp[i + 1][j] >= dp[i][j + 1] else dp[i][j + 1]
            if cand_keys[i] == block_keys[j]:
                best = max(best, dp[i + 1][j + 1] + 1)
            dp[i][j] = best
    pairs, sc, sb = [], [], []
    i = j = 0
    while i < n and j < m:
        if cand_keys[i] == block_keys[j] and dp[i][j] == dp[i + 1][j + 1] + 1:
            pairs.append((i, j)); i += 1; j += 1
        elif dp[i + 1][j] >= dp[i][j + 1]:
            sc.append(i); i += 1
        else:
            sb.append(j); j += 1
    sc.extend(range(i, n)); sb.extend(range(j, m))
    return pairs, sc, sb

def assign_blocks(blocks, cand_secs, pairs, overrides, doc_name, stats):
    """Map each footnote block to a section index. blocks: list of
    dicts with 'key' and 'refhead'. cand_secs: section idx per
    candidate. overrides: refhead-prefix -> section idx."""
    pair_by_block = {j: i for i, j in pairs}
    block_sec = {}
    for j, blk in enumerate(blocks):
        if j in pair_by_block:
            block_sec[j] = cand_secs[pair_by_block[j]]
            continue
        prev_sec = None
        for k in range(j - 1, -1, -1):
            if k in pair_by_block:
                prev_sec = cand_secs[pair_by_block[k]]; break
        next_sec = None
        for k in range(j + 1, len(blocks)):
            if k in pair_by_block:
                next_sec = cand_secs[pair_by_block[k]]; break
        if prev_sec is not None and prev_sec == next_sec:
            block_sec[j] = prev_sec
            stats["neighbour_assigned"] += 1
            continue
        hit = None
        for prefix, sec_idx in overrides.items():
            if blk["refhead"].startswith(prefix):
                hit = sec_idx; break
        if hit is None:
            raise SystemExit(
                f"{doc_name}: cannot assign footnote block {j} "
                f"({blk['key']}: {blk['refhead'][:60]}) — prev sec {prev_sec}, "
                f"next sec {next_sec}, no override. Aborting.")
        block_sec[j] = hit
        stats["override_assigned"] += 1
    return block_sec

def new_stats():
    return {"dropped_items": 0, "dropped_verses": 0, "whole_chapter": 0,
            "etc_dropped": 0, "neighbour_assigned": 0, "override_assigned": 0,
            "drop_examples": [], "zero_ref_blocks": []}

# ----------------------------------------------------------------- WCF

# Verified by eye against the printed OPC PDF (see README):
#  - 3.3 block f ("1 Tim. 5:21…"): marker printed attached to "angels"
#    in section 3 ("men and angelsf are predestinated…"); neighbours
#    straddle 3.2/3.3.
#  - 18.1 blocks a ("Mic. 3:11…") and b ("Amos 9:10…"): markers printed
#    attached to "salvationa" and "perishb" in section 1 of chapter 18;
#    neighbours straddle the chapter 17/18 boundary.
WCF_OVERRIDES = {"1 Tim. 5:21": (3, 3), "Mic. 3:11": (18, 1), "Amos 9:10": (18, 1)}

def parse_wcf(text):
    stats = new_stats()
    pages = text.split("\f")
    blocks = []          # {'key': letter, 'text': str, 'refhead': str}
    body_lines = []      # (line, sec_key or None)
    chap = 0
    sec = None
    cur = None
    for page in pages:
        in_foot = False
        for ln in page.split("\n"):
            fm = re.match(r"^\s{2,8}([a-z])\. (.*)$", ln)
            if fm:
                if cur:
                    blocks.append(cur)
                in_foot = True
                cur = {"key": fm.group(1), "text": fm.group(2)}
                continue
            if in_foot:
                if cur:
                    cur["text"] += " " + ln.strip()
                continue
            cm = re.match(r"^\s+Chapter (\d+)\s*$", ln)
            if cm:
                chap = int(cm.group(1)); sec = None
                body_lines.append((ln, None)); continue
            sm = re.match(r"^\s{2,6}(\d{1,2})\. [A-Z]", ln)
            if sm:
                sec = (chap, int(sm.group(1)))
            body_lines.append((ln, sec))
    if cur:
        blocks.append(cur)
    for b in blocks:
        b["refhead"] = b["text"].strip()
        b["text"] = re.sub(r"-\s+", "", b["text"])      # dehyphenate
        b["text"] = re.sub(r"\s+", " ", b["text"])

    # section list in order
    sections = []
    seen = set()
    for _, s in body_lines:
        if s is not None and s not in seen:
            seen.add(s); sections.append(s)
    sec_index = {s: i for i, s in enumerate(sections)}
    per_ch = Counter(c for c, _ in sections)
    assert len(sections) == 171, f"WCF sections {len(sections)} != 171"
    for ch in range(1, 34):
        seq = [n for c, n in sections if c == ch]
        assert seq == list(range(1, len(seq) + 1)), f"WCF ch {ch} sections not sequential: {seq}"

    # body text + candidate markers (letter attached to punctuation)
    lines = [l for l, _ in body_lines]
    secs = [s for _, s in body_lines]
    body_text = "\n".join(lines)
    offs = []
    pos = 0
    for l in lines:
        offs.append(pos); pos += len(l) + 1
    cand_keys, cand_secs = [], []
    for m in re.finditer(r"(?<=[,.;:!?)”\u201d'])([a-z])(?![A-Za-z])", body_text):
        li = bisect.bisect_right(offs, m.start()) - 1
        if secs[li] is None:
            continue
        cand_keys.append(m.group(1))
        cand_secs.append(sec_index[secs[li]])
    pairs, sc, sb = lcs_align(cand_keys, [b["key"] for b in blocks])
    stats["blocks"] = len(blocks)
    stats["markers_matched"] = len(pairs)
    stats["false_candidates"] = len(sc)
    overrides = {k: sec_index[v] for k, v in WCF_OVERRIDES.items()}
    block_sec = assign_blocks(blocks, cand_secs, pairs, overrides, "WCF", stats)

    edges = set()
    for j, blk in enumerate(blocks):
        items = parse_modern_refs(blk["text"], stats)
        if not items:
            stats["zero_ref_blocks"].append(f"{blk['key']}: {blk['refhead'][:60]}")
        for it in items:
            for gc, v in expand(it, stats):
                edges.add((block_sec[j], gc, v))
    return sections, edges, stats

# ----------------------------------------------------------------- 1689

LBC_OVERRIDES = {}   # none needed: unmatched footnotes are neighbour-assigned

def parse_lbc(text):
    stats = new_stats()
    start = text.find("CHAP. I.")
    end = text.find("An Appendix", start)
    assert start > 0 and end > start
    region = text[start:end]
    blocks = []          # {'key': int, 'text': str, 'refhead': str}
    body = []            # (line, para_key or None)
    cur = None
    chap = 0
    para = None
    for page in region.split("\f"):
        in_foot = False
        for ln in page.split("\n"):
            fm = re.match(r"^(\d{1,3})\s{2,}(\S.*)$", ln)
            if fm:
                if cur:
                    blocks.append(cur)
                in_foot = True
                cur = {"key": int(fm.group(1)), "text": fm.group(2)}
                continue
            if in_foot:
                if re.match(r"^\s*\d+\s*$", ln):
                    continue
                if cur:
                    cur["text"] += " " + ln.strip()
                continue
            cm = re.match(r"^\s*CHAP\. ([IVXL]+)\.\s*$", ln)
            if cm:
                chap += 1; para = None
                body.append((ln, None)); continue
            pm = re.match(r"^\s{3,6}(\d{1,2})\. ", ln)
            if pm:
                para = (chap, int(pm.group(1)))
                ln = re.sub(r"^\s{3,6}\d{1,2}\. ", " ", ln)
            body.append((ln, para))
    if cur:
        blocks.append(cur)
    for b in blocks:
        b["refhead"] = b["text"].strip()
        b["text"] = re.sub(r"-\s+", "", b["text"])
        b["text"] = re.sub(r"\s+", " ", b["text"])
    nums = [b["key"] for b in blocks]
    assert nums == list(range(1, len(nums) + 1)), "LBC footnote numbers not 1..N sequential"

    sections = []
    seen = set()
    for _, s in body:
        if s is not None and s not in seen:
            seen.add(s); sections.append(s)
    sec_index = {s: i for i, s in enumerate(sections)}
    assert len(sections) == 160, f"LBC paragraphs {len(sections)} != 160"
    for ch in range(1, 33):
        seq = [n for c, n in sections if c == ch]
        assert seq == list(range(1, len(seq) + 1)), f"LBC ch {ch} paragraphs not sequential: {seq}"

    cand_keys, cand_secs = [], []
    for ln, s in body:
        if s is None:
            continue
        if re.match(r"^\s{20,}\d{1,3}\s*$", ln):
            continue                     # right-aligned page number
        for m in re.finditer(r"(?:^|(?<=\s)|(?<=[,.;:]))(\d{1,3})(?=[A-Za-z]|\s|$|&)", ln):
            cand_keys.append(int(m.group(1)))
            cand_secs.append(sec_index[s])
    pairs, sc, sb = lcs_align(cand_keys, [b["key"] for b in blocks])
    stats["blocks"] = len(blocks)
    stats["markers_matched"] = len(pairs)
    stats["false_candidates"] = len(sc)
    block_sec = assign_blocks(blocks, cand_secs, pairs, {}, "LBC", stats)

    edges = set()
    for j, blk in enumerate(blocks):
        items = parse_old_refs(blk["text"], stats)
        if not items:
            stats["zero_ref_blocks"].append(f"{blk['key']}: {blk['refhead'][:60]}")
        for it in items:
            for gc, v in expand(it, stats):
                edges.add((block_sec[j], gc, v))
    return sections, edges, stats

# ----------------------------------------------------------------- main

def main():
    SOURCES.mkdir(parents=True, exist_ok=True)
    print("fetch:")
    fetch(WCF_PDF_URL, SOURCES / "wcf_opc_proofs.pdf")
    fetch(LBC_PDF_URL, SOURCES / "lbc1689_ccel.pdf")
    print("extract + parse:")
    wcf_sections, wcf_edges, wcf_stats = parse_wcf(pdf_text(SOURCES / "wcf_opc_proofs.pdf"))
    print(f"  WCF: {len(wcf_sections)} sections, {wcf_stats['blocks']} footnote blocks, "
          f"{wcf_stats['markers_matched']} markers matched, {len(wcf_edges)} edges")
    lbc_sections, lbc_edges, lbc_stats = parse_lbc(pdf_text(SOURCES / "lbc1689_ccel.pdf"))
    print(f"  1689: {len(lbc_sections)} paragraphs, {lbc_stats['blocks']} footnote blocks, "
          f"{lbc_stats['markers_matched']} markers matched, {len(lbc_edges)} edges")

    sections_out = []
    for c, n in wcf_sections:
        sections_out.append({"d": 0, "id": f"{c}.{n}", "label": f"Chapter {c} · Section {n}"})
    off = len(sections_out)
    for c, n in lbc_sections:
        sections_out.append({"d": 1, "id": f"{c}.{n}", "label": f"Chapter {c} · Paragraph {n}"})
    edges = sorted([list(e) for e in wcf_edges] +
                   [[s + off, gc, v] for s, gc, v in lbc_edges])
    doc = {
        "v": 1,
        "docs": [
            {"id": "wcf", "title": "Westminster Confession of Faith", "year": 1647,
             "url": "https://opc.org/wcf.html"},
            {"id": "lbc1689", "title": "1689 London Baptist Confession", "year": 1689,
             "url": "https://ccel.org/ccel/anonymous/bcf.html"},
        ],
        "sections": sections_out,
        "edges": edges,
    }
    OUT_PATH.write_text(json.dumps(doc, separators=(",", ":")) + "\n")
    print(f"wrote {OUT_PATH} ({OUT_PATH.stat().st_size} bytes, {len(edges)} edges)")

    # independent verification pass over the written file
    back = json.loads(OUT_PATH.read_text())
    assert back["v"] == 1 and len(back["docs"]) == 2
    assert back["edges"] == sorted(back["edges"]) and len({tuple(e) for e in back["edges"]}) == len(back["edges"])
    canon_chapters = json.loads(CANON_PATH.read_text())["chapters"]
    bad = []
    for s, gc, v in back["edges"]:
        if not (0 <= s < len(back["sections"])):
            bad.append((s, gc, v)); continue
        if not (0 <= gc < 1189):
            bad.append((s, gc, v)); continue
        if not (1 <= v <= canon_chapters[gc]["v"]):
            bad.append((s, gc, v))
    print(f"VERIFY: {len(back['edges'])} edges re-checked against data.json verse counts; "
          f"out-of-range: {len(bad)}")
    assert not bad, bad[:10]
    print("stats:")
    print(json.dumps({"wcf": {k: v for k, v in wcf_stats.items()},
                      "lbc1689": {k: v for k, v in lbc_stats.items()}}, indent=1))

if __name__ == "__main__":
    main()
