from pathlib import Path
import re

path = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
text = path.read_text(encoding='utf-8')
keys = [
    'sleepTime', 'wakeTime', 'sleepIntelligenceTitle',
    'sleepIntelligenceDescription', 'sleepIntelligencePurpose',
    'daily', 'workDaysLabel', 'days', 'save', 'cancel',
    'dayMonShort', 'dayTueShort', 'dayWedShort', 'dayThuShort',
    'dayFriShort', 'daySatShort', 'daySunShort', 'sleepRoutineIntro',
    'continue',
]
# Language blocks are maps keyed by locale in this generated source.
locale_headers = re.findall(r"'([a-z]{2}(?:-[A-Z]{2})?)'\s*:\s*\{", text)
locales = list(dict.fromkeys(locale_headers))
print(f'locale_blocks={len(locales)}')
for key in keys:
    count = len(re.findall(r"['\"]" + re.escape(key) + r"['\"]\s*:", text))
    print(f'{key}={count}/{len(locales)}')
missing = [key for key in keys if len(re.findall(r"['\"]" + re.escape(key) + r"['\"]\s*:", text)) < len(locales)]
print('missing=' + ','.join(missing))
