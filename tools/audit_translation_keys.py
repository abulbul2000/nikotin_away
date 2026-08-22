from pathlib import Path
import re

app = Path('lib/core/app_texts.dart').read_text(encoding='utf-8')
gen = Path('lib/core/generated_language_data.dart').read_text(encoding='utf-8')

# Restrict English map to the block between its declaration and the next map.
en_block = app.split("static const Map<String, String> _en = {", 1)[1].split("};", 1)[0]
en_keys = set(re.findall(r"^\s*'([^']+)'\s*:", en_block, re.M))

starts = list(re.finditer(r"^  '([a-z]{2,3})': <String, String>\{", gen, re.M))
print(f"english_reference_keys={len(en_keys)}")
print(f"generated_languages={len(starts)}")
for i, m in enumerate(starts):
    code = m.group(1)
    end = starts[i+1].start() if i + 1 < len(starts) else len(gen)
    block = gen[m.end():end]
    keys = set(re.findall(r"^\s*'([^']+)'\s*:", block, re.M))
    missing = sorted(en_keys - keys)
    extra = sorted(keys - en_keys)
    print(f"{code}: keys={len(keys)} missing={len(missing)} extra={len(extra)}")
    if missing:
        print('  missing:', ', '.join(missing[:20]))
    if extra:
        print('  extra:', ', '.join(extra[:20]))
