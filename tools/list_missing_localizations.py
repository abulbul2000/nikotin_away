from pathlib import Path
import re

app = Path('lib/core/app_texts.dart').read_text(encoding='utf-8')
data = Path('lib/core/generated_language_data.dart').read_text(encoding='utf-8')
en_start = app.index("static const Map<String, String> _en")
en_block = app[en_start:]
en_keys = set(re.findall(r"^    '([^']+)':", en_block, re.M))
languages = sorted(set(re.findall(r"^  '([a-z]{2,3})': <String, String>\{", data, re.M)))
for lang in languages:
    marker = f"  '{lang}': <String, String>{{"
    start = data.index(marker) + len(marker)
    next_match = re.search(r"\n  '[a-z]{2,3}': <String, String>\{", data[start:])
    end = start + (next_match.start() if next_match else len(data[start:]))
    keys = set(re.findall(r"^    '([^']+)':", data[start:end], re.M))
    missing = sorted(en_keys - keys)
    print(lang, len(missing), ','.join(missing))

print('MISSING_KEYS')
marker = "  'ar': <String, String>{"
start = data.index(marker) + len(marker)
next_match = re.search(r"\n  '[a-z]{2,3}': <String, String>\{", data[start:])
end = start + (next_match.start() if next_match else len(data[start:]))
keys = set(re.findall(r"^    '([^']+)':", data[start:end], re.M))
for key in sorted(en_keys - keys):
    print(key)
