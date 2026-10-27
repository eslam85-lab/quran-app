#!/usr/bin/env python3
"""
Generates and STRICTLY validates all Quran data for the app:
  assets/quran/quran.json   - 114 surahs / 6236 verses (Uthmani, Hafs)      [api.alquran.cloud]
  assets/quran/tafsir.json  - Tafsir al-Muyassar, one entry per verse       [api.alquran.cloud]
  assets/quran/mushaf.json  - 604 Madani mushaf pages, line by line         [api.quran.com v4]
Any failed assertion exits non-zero, so the GitHub build stops rather than shipping an incomplete Quran.
"""
import json, re, sys, time, urllib.request, pathlib

sys.stdout.reconfigure(encoding="utf-8")
from concurrent.futures import ThreadPoolExecutor

CLOUD = "https://api.alquran.cloud/v1/quran/"
QCOM = "https://api.quran.com/api/v4/verses/by_page/{p}?words=true&word_fields=text_uthmani,line_number&per_page=50&page={n}"
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "quran"
ARABIC = re.compile(r"[\u0600-\u06FF]")
AR_DIGITS = "٠١٢٣٤٥٦٧٨٩"
MAX_LINES = 15


def get_json(url, tries=6):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "quran-app-build/1.0"})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:
            last = e
            time.sleep(1.5 * (i + 1))
    sys.exit(f"FAILED to fetch {url}: {last}")


def ar_num(n):
    return "".join(AR_DIGITS[int(c)] for c in str(n))


def fetch_edition(edition):
    d = get_json(CLOUD + edition)
    assert d["code"] == 200, f"bad status for {edition}"
    return d["data"]["surahs"]


def build_text_and_tafsir():
    text, tafsir = fetch_edition("quran-uthmani"), fetch_edition("ar.muyassar")
    assert len(text) == 114 and len(tafsir) == 114, "need 114 surahs"
    surahs, tafsir_list, g = [], [], 0
    for s, t in zip(text, tafsir):
        assert s["number"] == t["number"]
        assert len(s["ayahs"]) == len(t["ayahs"]), f"tafsir mismatch surah {s['number']}"
        ayahs = []
        for i, (a, ta) in enumerate(zip(s["ayahs"], t["ayahs"]), 1):
            g += 1
            assert a["number"] == g and a["numberInSurah"] == i, f"sequence break at {g}"
            body = a["text"].strip()
            # API prepends the Basmalah (4 words) to verse 1 of every surah except 1 and 9
            if i == 1 and s["number"] not in (1, 9):
                words = body.split(" ")
                assert len(words) > 4, f"surah {s['number']} verse 1 too short"
                body = " ".join(words[4:])
            assert ARABIC.search(body) and len(body) > 1, f"empty verse {g}"
            assert ta["text"].strip(), f"empty tafsir {g}"
            ayahs.append({"g": g, "i": i, "p": a["page"], "t": body})
            tafsir_list.append(ta["text"].strip())
        surahs.append({"n": s["number"], "name": s["name"], "en": s["englishName"],
                       "type": s["revelationType"], "ayahs": ayahs})
    counts = {x["n"]: len(x["ayahs"]) for x in surahs}
    assert g == 6236, f"expected 6236 verses, got {g}"
    assert (counts[1], counts[2], counts[9], counts[114]) == (7, 286, 129, 6)
    return surahs, tafsir_list, counts


def fetch_page_verses(p):
    verses, n = [], 1
    while True:
        d = get_json(QCOM.format(p=p, n=n))
        verses += d["verses"]
        nxt = (d.get("pagination") or {}).get("next_page")
        if not nxt:
            return verses
        n = nxt


def build_page(p, verses, gmap):
    """quran.com verses -> rows. Row kinds: [0,[[text,g,isEnd],...]] text line, [1,surah] header,
    [2] basmala, [3] blank. Works whether or not the source leaves gaps for header/basmala lines."""
    by_line, starts = {}, {}
    for v in verses:
        s, a = map(int, v["verse_key"].split(":"))
        g = gmap[(s, a)]
        for w in v["words"]:
            ln = int(w["line_number"])
            assert 1 <= ln <= MAX_LINES, f"page {p}: bad line {ln}"
            end = w.get("char_type_name") == "end"
            t = f"\ufd3f{ar_num(a)}\ufd3e" if end else (w.get("text_uthmani") or w.get("text") or "").strip()
            assert t, f"page {p}: empty word in {s}:{a}"
            by_line.setdefault(ln, []).append([t, g, 1 if end else 0])
            if a == 1 and int(w.get("position", 0)) == 1:
                starts[ln] = s
    out = []
    for ln in range(1, max(by_line) + 1):
        if ln in starts:
            s = starts[ln]
            need = [[1, s]] if s in (1, 9) else [[1, s], [2]]
            for _ in need:  # reuse blank rows left as a gap before this line
                if out and out[-1] == [3]:
                    out.pop()
            out.extend(need)
        out.append([0, by_line[ln]] if ln in by_line else [3])
    return out


def build_mushaf(gmap, counts):
    with ThreadPoolExecutor(max_workers=8) as ex:
        results = list(ex.map(fetch_page_verses, range(1, 605)))
    pages, seen_g, end_seen, rub_start = [], set(), {}, {}
    for p, verses in enumerate(results, 1):
        assert verses, f"page {p} has no verses"
        first_s = int(verses[0]["verse_key"].split(":")[0])
        for v in verses:
            rr = v.get("rub_el_hizb_number")
            if rr and rr not in rub_start:
                s_, a_ = map(int, v["verse_key"].split(":"))
                rub_start[rr] = (gmap[(s_, a_)], p)
        rows = build_page(p, verses, gmap)
        assert 1 <= len(rows) <= MAX_LINES + 3, f"page {p}: {len(rows)} rows"
        for r in rows:
            if r[0] == 0:
                for w in r[1]:
                    seen_g.add(w[1])
                    if w[2]:
                        end_seen[w[1]] = end_seen.get(w[1], 0) + 1
        pages.append({"p": p, "j": int(verses[0]["juz_number"]), "s": first_s, "l": rows})
    assert len(pages) == 604, "need 604 pages"
    assert seen_g == set(range(1, 6237)), f"missing verses in mushaf: {sorted(set(range(1,6237)) - seen_g)[:10]}"
    assert all(end_seen.get(g) == 1 for g in range(1, 6237)), "every verse must end exactly once"
    if rub_start:
        assert sorted(rub_start) == list(range(1, 241)), "rub el hizb numbers must be exactly 1..240"
        starts = [rub_start[r][0] for r in range(1, 241)]
        assert starts[0] == 1 and starts == sorted(starts), "rub starts must increase"
    else:
        print("WARNING: no rub_el_hizb_number in API response; quarter index disabled")
    return pages, rub_start


HARAKAT = re.compile(r"[\u064B-\u0655\u0670]")


def cps(t):
    return " ".join("%04X" % ord(c) for c in t)


def report_marks(pages, surahs):
    """Diagnostic only (never fails the build): how many words carry no diacritics at all."""
    bare, total, samples = 0, 0, []
    for pg in pages:
        for r in pg["l"]:
            if r[0] != 0:
                continue
            for t, g, end in r[1]:
                if end:
                    continue
                total += 1
                if not HARAKAT.search(t):
                    bare += 1
                    if len(samples) < 12:
                        samples.append((pg["p"], g, t))
    print(f"DIAG mushaf words without any diacritic: {bare}/{total}")
    for p, g, t in samples:
        print(f"DIAG sample page {p} verse {g}: {t} | {cps(t)}")
    qb = qt = 0
    for s in surahs:
        for a in s["ayahs"]:
            for w in a["t"].split(" "):
                qt += 1
                if not HARAKAT.search(w):
                    qb += 1
    print(f"DIAG quran.json words without any diacritic: {qb}/{qt}")
    first = [r for r in pages[0]["l"] if r[0] == 0][0]
    print("DIAG page1 first line:", " ".join(w[0] for w in first[1]))
    print("DIAG page1 first words codepoints:", " || ".join(cps(w[0]) for w in first[1][:4]))
    a11 = surahs[0]["ayahs"][0]["t"]
    print("DIAG quran 1:1:", a11, "|", cps(a11))


def main():
    surahs, tafsir_list, counts = build_text_and_tafsir()
    gmap = {(s["n"], a["i"]): a["g"] for s in surahs for a in s["ayahs"]}
    pages, rubs = build_mushaf(gmap, counts)
    try:
        report_marks(pages, surahs)
    except Exception as e:  # diagnostics must never break the build
        print("DIAG failed:", e)
    OUT.mkdir(parents=True, exist_ok=True)
    dump = lambda name, obj: (OUT / name).write_text(json.dumps(obj, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    dump("quran.json", {"surahs": surahs})
    dump("tafsir.json", tafsir_list)
    dump("mushaf.json", pages)
    dump("index.json", {"rubs": [[r, rubs[r][0], rubs[r][1]] for r in sorted(rubs)]})
    print(f"OK: 114 surahs, 6236 verses, {len(tafsir_list)} tafsir entries, {len(pages)} mushaf pages")


if __name__ == "__main__":
    main()
