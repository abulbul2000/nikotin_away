from pathlib import Path
import re

path = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
text = path.read_text(encoding='utf-8')
if "  'ku-Arab': <String, String>{" in text:
    print('Sorani map already exists')
    raise SystemExit
m = re.search(r"  'ku': <String, String>\{\n(.*?)\n  \},\n\};\n", text, re.S)
if not m:
    raise RuntimeError('Kurmanci map not found')
body = m.group(1)
replacements = {
    'sleepScheduleTitle': 'کاتی خەوتن و هەستان',
    'sleepScheduleDescription': 'کاتی خەوتن و هەستان بۆ هەموو ڕۆژێک یان ڕۆژە دیاریکراوەکانی هەفتە دابنێ.',
    'scheduleDaily': 'هەموو ڕۆژێک',
    'scheduleByDay': 'ڕۆژەکان هەڵبژێرە',
    'wakeAlarmTitle': 'ئاگادارکەرەوەی هەستان',
    'wakeAlarmBody': 'ئاگادارکەرەوەکە لە کاتی هەستانی هەڵبژێردراوت دەنگ دەدات.',
    'wakeAlarmEnabledTitle': 'ئاگادارکەرەوەی هەستان چالاک بکە',
    'wakeAlarmEnabledDescription': 'ئەگەر ڕازی بیت، ئاگادارکەرەوەکە لە کاتی هەڵبژێردراوت دەنگ دەدات.',
    'sleepRoutineTonightTitle': 'کاتی خەوتنی ئەمشەو',
    'sleepRoutineTonightBody': 'ئەو کاتە هەڵبژێرە کە بەڕاستی دەتهەوێت ئەمشەو بیخەویت.',
}
for key, value in replacements.items():
    pat = rf"(    '{re.escape(key)}':\s*)'((?:\\.|[^'])*)',"
    body, n = re.subn(pat, lambda x: x.group(1) + "'" + value.replace("'", "\\'") + "',", body, count=1)
    if n != 1:
        raise RuntimeError(f'missing key {key}')
new_map = "  'ku-Arab': <String, String>{\n" + body + "\n  },\n"
text = text[:m.end()-len('};\n')] + new_map + '};\n'
path.write_text(text, encoding='utf-8')
print('added Sorani map')
