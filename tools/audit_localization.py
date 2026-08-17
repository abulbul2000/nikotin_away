from pathlib import Path
import re

text = Path('lib/core/generated_language_data.dart').read_text(encoding='utf-8')
blocks = re.split(r"\n  '(?=[a-z]{2,3}': <String, String>\{)", text)
for block in blocks:
    m = re.match(r"'?([a-z]{2,3})': <String, String>\{", block)
    if m:
        print(m.group(1), len(re.findall(r"^    '[^']+':", block, re.M)))
languages = sorted(set(re.findall(r"^  '([a-z]{2,3})': <String, String>\{", text, re.M)))
print('all language literals:', languages)
# The current AppTexts implementation stores generated languages separately;
# _en is the English table and there is no legacy _data marker.
app = Path('lib/core/app_texts.dart').read_text(encoding='utf-8')
en_start = app.index("static const Map<String, String> _en")
en_block = app[en_start:]
en_keys = set(re.findall(r"^    '([^']+)':", en_block, re.M))
print('English keys:', len(en_keys))
for lang in languages:
    marker = f"  '{lang}': <String, String>{{"
    start = text.index(marker) + len(marker)
    next_match = re.search(r"\n  '[a-z]{2,3}': <String, String>\{", text[start:])
    end = start + (next_match.start() if next_match else len(text[start:]))
    keys = set(re.findall(r"^    '([^']+)':", text[start:end], re.M))
    print(f'{lang}: missing legacy keys={len(en_keys - keys)}')
