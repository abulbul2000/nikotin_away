from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
APP = (ROOT/'lib/core/app_texts.dart').read_text(encoding='utf-8')
GEN = (ROOT/'lib/core/generated_language_data.dart').read_text(encoding='utf-8')
LINE_RE = re.compile(r"^\s*'([^']+)':\s*'((?:\\.|[^'])*)',?\s*$")
EN_HINTS = re.compile(r"\b(the|and|or|your|you|with|from|this|that|test|start|save|settings|notifications|data|result|failed|warning|minutes|seconds|today|tomorrow|week|month|year)\b", re.I)
TR_HINTS = re.compile(r"\b(ve|veya|için|olan|olarak|veri|ayarlar|bildirimler|sonuç|başla|kaydet|bugün|yarın|hafta|ay|yıl|sigara|bırakma)\b", re.I)

def block(text, marker, end_marker=None):
    s=text.index(marker); e=text.index(end_marker,s) if end_marker else text.find('};',s)
    return {m.group(1):m.group(2) for m in (LINE_RE.match(x) for x in text[s:e].splitlines()) if m}

def lang(text, code):
    marker=f"  '{code}': <String, String>{{"; s=text.index(marker)+len(marker)
    m=re.search(r"\n  '[a-z]{2,3}': <String, String>\{",text[s:]); e=s+(m.start() if m else len(text[s:]))
    return {m.group(1):m.group(2) for m in (LINE_RE.match(x) for x in text[s:e].splitlines()) if m}

tr=block(APP,"static const Map<String, String> _tr","static const Map<String, String> _en")
en=block(APP,"static const Map<String, String> _en")
allmaps={'en':en,'tr':tr}
for code in sorted(re.findall(r"^  '([a-z]{2,3})': <String, String>\{",GEN,re.M)):
    allmaps[code]=lang(GEN,code)
for code, vals in allmaps.items():
    english=[]; turkish=[]
    for key,val in vals.items():
        if code not in ('en',) and val==en.get(key) and val:
            english.append((key,val))
        if code not in ('tr','en') and val==tr.get(key) and val:
            turkish.append((key,val))
    if english:
        print(f'[{code}] ENGLISH_EQUAL {len(english)}')
        for key,val in english: print(f'  {key}\t{val}')
    if turkish:
        print(f'[{code}] TURKISH_EQUAL {len(turkish)}')
        for key,val in turkish: print(f'  {key}\t{val}')
