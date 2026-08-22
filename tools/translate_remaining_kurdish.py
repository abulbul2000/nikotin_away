from __future__ import annotations
import concurrent.futures as cf
import json, os, re, time
from pathlib import Path
import requests

ROOT = Path('/home/ubuntu/nikotin_away')
DART = ROOT / 'lib/core/generated_language_data.dart'
APP = ROOT / 'lib/core/app_texts.dart'
LOG = ROOT / 'docs/kurdish_translation_remaining_log.json'
MODEL = 'gpt-5-mini'
BATCH_SIZE = 8
MAX_WORKERS = 1

# Supports canonical strings whose value is on the following indented line.
PAIR_RE = re.compile(r"^    '([^']+)':\s*(?:\n\s*)?'((?:\\.|[^'])*)',\s*$", re.M)

def block(source: str, code: str):
    m = re.search(rf"  '{re.escape(code)}': <String, String>{{\n(.*?\n  }}),", source, re.S)
    if not m:
        raise RuntimeError(f'missing block {code}')
    return m

def pairs(s: str):
    return dict(PAIR_RE.findall(s))

text = DART.read_text(encoding='utf-8')
app = APP.read_text(encoding='utf-8')
en_m = re.search(r"  static const Map<String, String> _en = \{\n(.*?)\n  \};", app, re.S)
if not en_m:
    raise RuntimeError('missing English map')
en = pairs(en_m.group(1))

session = requests.Session()
base = os.environ['OPENAI_API_BASE'].rstrip('/')
headers = {'Authorization': f"Bearer {os.environ['OPENAI_API_KEY']}", 'Content-Type': 'application/json'}

def translate(code, items):
    target = 'Kurmanji Kurdish in Latin script' if code == 'ku' else 'Sorani Kurdish in Arabic script'
    prompt = (f'Translate every item into {target}. Return ONLY a JSON array with exactly key and translation. '
              'Preserve placeholders, numbers, URLs, escape sequences, and Nicotine Away exactly. '
              'Use natural user-facing wording for a smoking-cessation mobile app; do not omit items.\n' +
              json.dumps([{'key':k,'english':v} for k,v in items], ensure_ascii=False))
    body = {'model': MODEL, 'messages': [
        {'role':'system','content':'You are a meticulous Kurdish mobile-app translator. Output valid JSON only.'},
        {'role':'user','content':prompt}], 'max_completion_tokens':10000}
    for attempt in range(8):
        try:
            r = session.post(f'{base}/chat/completions', headers=headers, json=body, timeout=180)
            r.raise_for_status()
            response = r.json()
            if not response.get('choices'):
                raise RuntimeError(f"translation response missing choices: {response}")
            data = json.loads(response['choices'][0]['message']['content'])
            out = {str(x['key']): str(x['translation']) for x in data}
            if set(out) != {k for k,_ in items}: raise ValueError('key mismatch')
            return out
        except Exception:
            if attempt == 7: raise
            time.sleep(2 ** attempt)

logs = {}
for code in ('ku','ku-arab'):
    m = block(text, code)
    current = pairs(m.group(1))
    candidates = [(k, en[k]) for k in en if k in current and current[k] == en[k] and k != 'appName']
    print(f'{code}: {len(candidates)} remaining', flush=True)
    batches = [candidates[i:i+BATCH_SIZE] for i in range(0,len(candidates),BATCH_SIZE)]
    translated = {}
    with cf.ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for i, result in enumerate(ex.map(lambda b: translate(code,b), batches), 1):
            translated.update(result); print(f'{code}: {i}/{len(batches)}', flush=True)
    logs[code] = len(translated)
    m = block(text, code)
    body = m.group(1)
    def repl(x):
        key, old = x.group(1), x.group(2)
        if key not in translated: return x.group(0)
        value = translated[key].replace('\\','\\\\').replace("'","\\'").replace('\n','\\n').replace('\r','\\r')
        return f"    '{key}': '{value}',"
    body = PAIR_RE.sub(repl, body)
    text = text[:m.start(1)] + body + text[m.end(1):]
    DART.write_text(text, encoding='utf-8')
LOG.write_text(json.dumps(logs, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(logs, ensure_ascii=False))
