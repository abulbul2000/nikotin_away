import json
import re
from pathlib import Path
from openai import OpenAI

locales = ['ko','hi','bn','pa','te','mr','ta','gu','kn','ml','th','vi','id','ms','fil','uk','ro','el','hu','cs','sv','da','no','fi','nl','be','sr','hr']
source = {
  'sleepScheduleTitle':'Sleep and Wake Times',
  'sleepScheduleDescription':'Plan sleep and wake times for every day or for selected days of the week.',
  'scheduleDaily':'Every day',
  'scheduleByDay':'Select days',
  'wakeAlarmTitle':'Wake-up alarm',
  'wakeAlarmBody':'The alarm will ring at your chosen wake-up time.',
  'wakeAlarmEnabledTitle':'Enable wake-up alarm',
  'wakeAlarmEnabledDescription':'If you agree, the alarm will ring at your selected wake-up time.',
  'sleepRoutineTonightTitle':'Tonight’s sleep time',
  'sleepRoutineTonightBody':'Choose the time you actually plan to go to sleep tonight.',
}

prompt = '''Translate the following ten short mobile-app strings into every requested locale. Return ONLY valid JSON: an object whose keys are locale codes and whose values are objects with exactly the same ten keys. Keep the meaning natural and concise. Do not transliterate. Preserve punctuation and do not add explanations. Locale codes: ''' + ','.join(locales) + '\nStrings:\n' + json.dumps(source, ensure_ascii=False)
client = OpenAI()
resp = client.chat.completions.create(
    model='gpt-5-mini',
    messages=[
        {'role':'system','content':'You are a professional UI translator. Output only valid JSON.'},
        {'role':'user','content':prompt},
    ],
    max_completion_tokens=16000,
)
raw = resp.choices[0].message.content.strip()
if raw.startswith('```'):
    raw = re.sub(r'^```(?:json)?\s*|\s*```$', '', raw, flags=re.S).strip()
data = json.loads(raw)
if set(data) != set(locales):
    raise RuntimeError(f'Locale mismatch: expected {len(locales)}, got {len(data)}')
for locale in locales:
    if set(data[locale]) != set(source):
        raise RuntimeError(f'Key mismatch in {locale}')

path = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
text = path.read_text(encoding='utf-8')
def q(value):
    return "'" + str(value).replace('\\','\\\\').replace("'", "\\'").replace('\n','\\n') + "'"
for locale in locales:
    start = text.find(f"  '{locale}': <String, String>{{")
    if start < 0: raise RuntimeError(f'missing map {locale}')
    body_start = start + text[start:].find('\n') + 1
    next_match = re.search(r"^  '[a-z]{2,3}': <String, String>\{", text[body_start:], re.M)
    end = body_start + next_match.start() if next_match else len(text)
    block = text[body_start:end]
    for key, value in data[locale].items():
        pattern = rf"(    '{re.escape(key)}':\s*)'((?:\\.|[^'])*)',"
        replacement = rf"\g<1>{q(value)},"
        block, n = re.subn(pattern, replacement, block, count=1)
        if n != 1: raise RuntimeError(f'missing key {locale}.{key}')
    text = text[:body_start] + block + text[end:]
path.write_text(text, encoding='utf-8')
print(f'localized {len(locales)} locales x {len(source)} keys')
