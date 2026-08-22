from pathlib import Path
import re

generated = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart').read_text(encoding='utf-8')
app_texts = Path('/home/ubuntu/nikotin_away/lib/core/app_texts.dart').read_text(encoding='utf-8')
blocks = {}
for code, text, pattern in (
    ('en', app_texts, r"  static const Map<String, String> _en = \{\n(.*?)\n  \};"),
    ('ku', generated, r"  'ku': <String, String>\{\n(.*?)\n  \},"),
    ('ku-arab', generated, r"  'ku-arab': <String, String>\{\n(.*?)\n  \},"),
):
    m = re.search(pattern, text, re.S)
    if not m:
        raise SystemExit(f'missing {code}')
    pairs = dict(re.findall(r"^    '([^']+)':\s*'((?:\\.|[^'])*)',", m.group(1), re.M))
    blocks[code] = pairs
for code in ('ku','ku-arab'):
    same = [k for k,v in blocks[code].items() if blocks['en'].get(k) == v]
    print(f'{code}: {len(blocks[code])} keys, {len(same)} values identical to English')
    print('sample:', ', '.join(same[:20]))
