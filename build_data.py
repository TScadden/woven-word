import json, re
from collections import defaultdict

BOOKS = [
("Gen","Genesis",50),("Exod","Exodus",40),("Lev","Leviticus",27),("Num","Numbers",36),
("Deut","Deuteronomy",34),("Josh","Joshua",24),("Judg","Judges",21),("Ruth","Ruth",4),
("1Sam","1 Samuel",31),("2Sam","2 Samuel",24),("1Kgs","1 Kings",22),("2Kgs","2 Kings",25),
("1Chr","1 Chronicles",29),("2Chr","2 Chronicles",36),("Ezra","Ezra",10),("Neh","Nehemiah",13),
("Esth","Esther",10),("Job","Job",42),("Ps","Psalms",150),("Prov","Proverbs",31),
("Eccl","Ecclesiastes",12),("Song","Song of Solomon",8),("Isa","Isaiah",66),("Jer","Jeremiah",52),
("Lam","Lamentations",5),("Ezek","Ezekiel",48),("Dan","Daniel",12),("Hos","Hosea",14),
("Joel","Joel",3),("Amos","Amos",9),("Obad","Obadiah",1),("Jonah","Jonah",4),
("Mic","Micah",7),("Nah","Nahum",3),("Hab","Habakkuk",3),("Zeph","Zephaniah",3),
("Hag","Haggai",2),("Zech","Zechariah",14),("Mal","Malachi",4),
("Matt","Matthew",28),("Mark","Mark",16),("Luke","Luke",24),("John","John",21),
("Acts","Acts",28),("Rom","Romans",16),("1Cor","1 Corinthians",16),("2Cor","2 Corinthians",13),
("Gal","Galatians",6),("Eph","Ephesians",6),("Phil","Philippians",4),("Col","Colossians",4),
("1Thess","1 Thessalonians",5),("2Thess","2 Thessalonians",3),("1Tim","1 Timothy",6),
("2Tim","2 Timothy",4),("Titus","Titus",3),("Phlm","Philemon",1),("Heb","Hebrews",13),
("Jas","James",5),("1Pet","1 Peter",5),("2Pet","2 Peter",3),("1John","1 John",5),
("2John","2 John",1),("3John","3 John",1),("Jude","Jude",1),("Rev","Revelation",22)]
ABBR = {b[0]: i for i, b in enumerate(BOOKS)}
CH_OFF = []
_off = 0
for _,_,n in BOOKS:
    CH_OFF.append(_off); _off += n
TOTAL_CH = _off
assert TOTAL_CH == 1189, TOTAL_CH

def parse_ref(s, last_book=None):
    # e.g. Gen.1.1  or range tail 1.5 -> reuse book/chapter handling outside
    s = s.strip()
    m = re.match(r'^([A-Za-z0-9]+)\.(\d+)\.(\d+)$', s)
    if not m: return None
    ab, ch, v = m.group(1), int(m.group(2)), int(m.group(3))
    if ab not in ABBR: return None
    return ABBR[ab], ch, v

def parse_side(s):
    # may be a range 'Gen.1.1-Gen.1.5' or 'Gen.1.1-5'; take the start ref
    s = s.strip()
    first = s.split('-')[0].strip()
    return parse_ref(first)

maxverse = defaultdict(int)
chapter_arcs = defaultdict(int)
refs = []
skipped = 0
for line in open('cross_references.txt'):
    if line.startswith('#') or line.startswith('From Verse') or not line.strip(): continue
    parts = line.rstrip('\n').split('\t')
    if len(parts) < 3: skipped += 1; continue
    a = parse_side(parts[0]); b = parse_side(parts[1])
    if not a or not b: skipped += 1; continue
    try: votes = int(parts[2])
    except: votes = 0
    (ba, ca, va), (bb, cb, vb) = a, b
    cha = CH_OFF[ba] + ca - 1; chb = CH_OFF[bb] + cb - 1
    maxverse[cha] = max(maxverse[cha], va); maxverse[chb] = max(maxverse[chb], vb)
    chapter_arcs[(cha, chb)] += 1
    refs.append([cha, va, chb, vb, votes])
print('parsed refs:', len(refs), 'skipped:', skipped)
chapters = []
for bi,(ab,name,n) in enumerate(BOOKS):
    for c in range(1, n+1):
        idx = CH_OFF[bi] + c - 1
        chapters.append({'b': bi, 'c': c, 'v': max(1, maxverse.get(idx, 1))})
missing = [i for i in range(1189) if maxverse.get(i,0)==0]
print('chapters with no verse data (patched to 1):', len(missing))
out = {
  'books': [{'abbr': ab, 'name': nm, 'chapters': n, 'start': CH_OFF[i]} for i,(ab,nm,n) in enumerate(BOOKS)],
  'chapters': chapters,
  'chapterArcs': [[a,b,c] for (a,b),c in sorted(chapter_arcs.items())],
  'refs': refs,
}
json.dump(out, open('data.json','w'), separators=(',',':'))
import os
print('data.json MB:', round(os.path.getsize('data.json')/1e6, 2))
print('chapter arc pairs:', len(out['chapterArcs']))
