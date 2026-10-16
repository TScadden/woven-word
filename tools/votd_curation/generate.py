#!/usr/bin/env python3
"""Generates lib/data/verse_of_day_curation.dart from curation.py and
verifies the final pools under the spec's rule end to end."""
import json, re, sys
sys.path.insert(0, '/home/hatch/workspace/woven-word/tools/votd_curation')
from curation import FLAGS

A = '/home/hatch/workspace/woven-word/flutter/assets'
data = json.load(open(f'{A}/data.json'))
kjv = json.load(open(f'{A}/kjv.json'))
conf = json.load(open(f'{A}/conference.json'))

books = data['books']; chapters = data['chapters']
book_chapters = {}
for gi, ch in enumerate(chapters):
    book_chapters.setdefault(ch['b'], []).append(gi)
book_name = [b['name'] for b in books]
name_to_book = {n: i for i, n in enumerate(book_name)}

def ref_of(gi, v):
    ch = chapters[gi]
    return f"{book_name[ch['b']]} {ch['c']}:{v}"

def kjv_text(gi, v):
    ch = chapters[gi]
    return kjv[ch['b']][ch['c'] - 1][v - 1]

# connections, exactly as BibleData.verseConnections counts them
conns = {}
for (fc, fv, tc, tv, votes) in data['refs']:
    conns.setdefault((fc, fv), set()).add(tc * 1000 + tv)
    conns.setdefault((tc, tv), set()).add(fc * 1000 + fv)
conn = {k: len(s) for k, s in conns.items()}

talks = conf['talks']
cite = {}
for (tid, gch, v) in conf['edges']:
    cite.setdefault((gch, v), set()).add(tid)
cite = {k: len(s) for k, s in cite.items()}

NUMBER_WORDS = {'one','two','three','four','five','six','seven','eight','nine','ten',
    'eleven','twelve','thirteen','fourteen','fifteen','sixteen','seventeen','eighteen',
    'nineteen','twenty','thirty','forty','fifty','sixty','seventy','eighty','ninety',
    'hundred','thousand'}
ITINERARY = re.compile(r'\b(removed|departed|journeyed) from [a-z\-]+,? and (encamped|pitched)\b')

def predicates(t):
    low = t.lower()
    if re.search(r'\bbegat\b', low):
        return True
    if ITINERARY.search(low):
        return True
    nums = sum(1 for w in re.findall(r'[a-z]+', low) if w in NUMBER_WORDS)
    if ('the children of' in low and nums >= 2) or \
       low.startswith('these are the names of') or low.startswith('and these are the names of'):
        return True
    toks = t.split()
    if len(toks) >= 6:
        internal = [w.strip('.,;:!?()') for w in toks[1:]]
        internal = [w for w in internal if w]
        if internal and sum(1 for w in internal if w[0].isupper()) / len(internal) >= 0.45:
            return True
    return False

# resolve flags
excluded = {}
for (bname, c, v, code, reason) in FLAGS:
    b = name_to_book[bname]
    gi = book_chapters[b][c - 1]
    key = (gi, v)
    assert key not in excluded
    excluded[key] = (code, reason, f"{bname} {c}:{v}")
    assert v <= chapters[gi]['v'], f"verse out of range {bname} {c}:{v}"
print(f'exclusions resolved: {len(excluded)}')

def build_pool(canon_books, mode):
    """mode 'cite': floor = cited by >= 25 distinct talks.
    mode 'conn': floor = >= 55 cross-reference connections.
    mode 'fallback': no floors; top 365 by connections (degraded path)."""
    cand = []
    for gi, ch in enumerate(chapters):
        if ch['b'] not in canon_books:
            continue
        for v in range(1, ch['v'] + 1):
            key = (gi, v)
            if mode == 'cite' and cite.get(key, 0) < 25:
                continue
            if mode == 'conn' and conn.get(key, 0) < 55:
                continue
            cand.append(key)
    def passes(key):
        if key in excluded:
            return False
        if predicates(kjv_text(*key)):
            return False
        return True
    cand = [k for k in cand if passes(k)]
    if mode == 'cite':
        cand.sort(key=lambda k: (-cite.get(k, 0), -conn.get(k, 0), k[0], k[1]))
    else:
        cand.sort(key=lambda k: (-conn.get(k, 0), k[0], k[1]))
    if mode == 'fallback':
        cand = cand[:365]
    return cand

core_books = set(range(66))
jew_books = set(range(39))
core_pool = build_pool(core_books, 'cite')
jew_pool = build_pool(jew_books, 'conn')
print(f'core pool (cite>=25, filtered): {len(core_pool)}')
print(f'jewish pool (conn>=55, filtered): {len(jew_pool)}')
lk = core_pool[-1]
print(f'core pool tail: {ref_of(*lk)} cite {cite.get(lk,0)} conn {conn.get(lk,0)}')
print(f'core top: {ref_of(*core_pool[0])} cite {cite.get(core_pool[0],0)}')
lk = jew_pool[-1]
print(f'jewish pool tail: {ref_of(*lk)} conn {conn.get(lk,0)}')
print(f'jewish top: {ref_of(*jew_pool[0])} conn {conn.get(jew_pool[0],0)}')

ANCHORS_CORE = [("John",3,16),("John",11,35),("John",14,6),("Matthew",22,37),
    ("Matthew",22,39),("Matthew",28,19),("Matthew",16,16),("Proverbs",3,5),
    ("Isaiah",40,31),("Galatians",5,22),("Romans",8,39),("Psalms",46,10),
    ("Revelation",21,4),("1 Corinthians",13,13),("John",1,29),("Matthew",5,3)]
ANCHORS_JEW = [("Isaiah",9,6),("Daniel",9,24),("Isaiah",40,31),("Micah",6,8),
    ("Psalms",46,1),("Proverbs",3,5),("Genesis",1,1),("Zechariah",4,6),
    ("Joshua",1,9),("Isaiah",52,7),("1 Samuel",16,7),("Isaiah",53,12)]
def key_of(bname,c,v):
    return (book_chapters[name_to_book[bname]][c-1], v)
core_set, jew_set = set(core_pool), set(jew_pool)
for b,c,v in ANCHORS_CORE:
    k = key_of(b,c,v)
    assert k in core_set, f'core anchor missing: {b} {c}:{v}'
for b,c,v in ANCHORS_JEW:
    k = key_of(b,c,v)
    assert k in jew_set, f'jewish anchor missing: {b} {c}:{v}'
print('all anchors present in their pools')
for k in excluded:
    assert k not in core_set and k not in jew_set
print('no excluded verse in either pool')
# cross-check: every pooled verse passes predicates (construction) and is in-canon
assert all(chapters[k[0]]['b'] in core_books for k in core_pool)
assert all(chapters[k[0]]['b'] in jew_books for k in jew_pool)
# fallback pool (no citation signal): connections rank + filters
fb_pool = build_pool(core_books, 'fallback')
print(f'fallback core pool (connections rank, top 365): {len(fb_pool)}; '
      f'tail {ref_of(*fb_pool[-1])} conn {conn.get(fb_pool[-1],0)}')
# how many of the old shipped top-365 survive into the new core pool?
old = sorted(conn.keys(), key=lambda k: (-conn[k], k[0], k[1]))
old_core = [k for k in old if chapters[k[0]]['b'] in core_books][:365]
print(f'old shipped pool verses surviving into new core pool: {len(set(old_core) & core_set)}/365')

# ---- emit the Dart curation table ----
lines = []
lines.append('/// Verse of the Day — the curatorial exclusion table.')
lines.append('///')
lines.append('/// GENERATED by tools/votd_curation/generate.py from the audited')
lines.append('/// flag list in tools/votd_curation/curation.py. Do not edit by')
lines.append('/// hand; amend the audit source and regenerate.')
lines.append('///')
lines.append('/// Each entry is a verse that passes the signal ranking and the')
lines.append('/// encoded predicates yet does not stand alone as a complete,')
lines.append('/// quotable thought (team/specs/verse-of-day-quotable.md §2.3).')
lines.append('/// Keys are (globalChapter, verse) in BibleData chapter order.')
lines.append('library;')
lines.append('')
lines.append('const Map<(int, int), String> votdCuratorialExclusions = {')
for key in sorted(excluded):
    code, reason, ref = excluded[key]
    reason = reason.replace("'", "\\'")
    lines.append(f"  ({key[0]}, {key[1]}): '{ref} — {reason}',")
lines.append('};')
out = '/home/hatch/workspace/woven-word/flutter/lib/data/verse_of_day_curation.dart'
open(out, 'w').write('\n'.join(lines) + '\n')
print('wrote', out)

# dump final pools for the Petra sample audit later
import pickle
pickle.dump({'core': core_pool, 'jew': jew_pool, 'cite': cite, 'conn': conn},
            open('/tmp/votd/final_pools.pkl', 'wb'))
print('pools dumped to /tmp/votd/final_pools.pkl')
