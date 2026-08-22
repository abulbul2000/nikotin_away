from __future__ import annotations

import concurrent.futures as cf
import json
import os
import re
import time
from pathlib import Path

import requests

ROOT = Path('/home/ubuntu/nikotin_away')
DART = ROOT / 'lib/core/generated_language_data.dart'
OUT = ROOT / 'docs/kurdish_translation_batch_log.json'
MODEL = 'gpt-5-mini'
BATCH_SIZE = 12
MAX_WORKERS = 4

text = DART.read_text(encoding='utf-8')
app = (ROOT / 'lib/core/app_texts.dart').read_text(encoding='utf-8')

def parse_block(source: str, code: str):
    pattern = rf"  '{re.escape(code)}': <String, String>{{\n(.*?)\n  }},"
    m = re.search(pattern, source, re.S)

    if not m:
        raise RuntimeError(f'missing language block: {code}')
    pairs = []
    for line in m.group(1).splitlines():
        mm = re.match(r"^    '([^']+)':\s*'((?:\\.|[^'])*)',\s*$", line)
        if mm:
            pairs.append((mm.group(1), mm.group(2)))
    return m, pairs

# app_texts is the canonical English source.
en_m = re.search(r"  static const Map<String, String> _en = \{\n(.*?)\n  \};", app, re.S)
if not en_m:
    raise RuntimeError('missing English source')
en = dict(re.findall(r"^    '([^']+)':\s*'((?:\\.|[^'])*)',", en_m.group(1), re.M))

blocks = {}
for code in ('ku', 'ku-arab'):
    m, pairs = parse_block(text, code)
    blocks[code] = {'match': m, 'pairs': pairs, 'values': dict(pairs)}

session = requests.Session()
base = os.environ['OPENAI_API_BASE'].rstrip('/')
headers = {'Authorization': f"Bearer {os.environ['OPENAI_API_KEY']}", 'Content-Type': 'application/json'}

# These are brand/product tokens, not translatable prose.
KEEP = {'appName'}

def call_batch(language: str, items: list[tuple[str, str]]):
    target = 'Kurmanji Kurdish in Latin script' if language == 'ku' else 'Sorani Kurdish in Arabic script'
    payload_items = [{'key': k, 'english': v} for k, v in items]
    prompt = (
        f'Translate every item into {target}. Return ONLY a JSON array with objects containing exactly key and translation. '
        'Keep each key unchanged. Preserve every placeholder such as {name}, {score}, {taskTitle}, every number, URL, newline escape, '
        'markdown marker, and product name Nicotine Away exactly. Do not transliterate or translate code-like identifiers. '
        'Use natural, user-facing wording suitable for a smoking-cessation mobile app. Do not omit or merge items.\n\n'
        + json.dumps(payload_items, ensure_ascii=False)
    )
    body = {'model': MODEL, 'messages': [
        {'role': 'system', 'content': 'You are a meticulous Kurdish mobile-app translator. Output valid JSON only.'},
        {'role': 'user', 'content': prompt},
    ], 'max_completion_tokens': 10000}
    for attempt in range(4):
        try:
            r = session.post(f'{base}/chat/completions', headers=headers, json=body, timeout=180)
            r.raise_for_status()
            response = r.json()
            if not response.get('choices'):
                raise RuntimeError(f'model response missing choices: {response}')
            content = response['choices'][0]['message']['content']
            data = json.loads(content)
            result = {str(x['key']): str(x['translation']) for x in data}
            if set(result) != {k for k, _ in items}:
                raise ValueError('batch key mismatch')
            return result
        except Exception:
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)

all_logs = {}
for code in ('ku', 'ku-arab'):
    candidates = [(k, v) for k, v in en.items() if k not in KEEP and blocks[code]['values'].get(k) == v]
    translated = {}
    batches = [candidates[i:i+BATCH_SIZE] for i in range(0, len(candidates), BATCH_SIZE)]
    print(f'{code}: {len(candidates)} candidates, {len(batches)} batches', flush=True)
    def worker(batch):
        return call_batch(code, batch)
    with cf.ThreadPoolExecutor(max_workers=MAX_WORKERS) as ex:
        for idx, result in enumerate(ex.map(worker, batches), 1):
            translated.update(result)
            print(f'{code}: {idx}/{len(batches)}', flush=True)
    all_logs[code] = {'translated': len(translated), 'keys': sorted(translated)}
    # Replace only the value literal in this language block, preserving Dart formatting.
    # Re-parse immediately before editing because the previous block changes offsets.
    block_match, current_pairs = parse_block(text, code)
    old_block = block_match.group(1)
    def replace_line(match):
        key, old = match.group(1), match.group(2)
        value = translated.get(key)
        if value is None:
            return match.group(0)
        # JSON string escaping is compatible with Dart for the common escapes; normalize apostrophes.
        escaped = value.replace('\\', '\\\\').replace("'", "\\'").replace('\n', '\\n').replace('\r', '\\r')
        return f"    '{key}': '{escaped}',"
    new_block = re.sub(r"^    '([^']+)':\s*'((?:\\.|[^'])*)',\s*$", replace_line, old_block, flags=re.M)
    text = text[:block_match.start(1)] + new_block + text[block_match.end(1):]
    DART.write_text(text, encoding='utf-8')

OUT.write_text(json.dumps(all_logs, ensure_ascii=False, indent=2), encoding='utf-8')
print(json.dumps(all_logs, ensure_ascii=False))
