from __future__ import annotations
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_TEXTS = ROOT / 'lib/core/app_texts.dart'
GENERATED = ROOT / 'lib/core/generated_language_data.dart'
OUT_JSON = ROOT / 'tooling/i18n_validation_report.json'
OUT_MD = ROOT / 'tooling/i18n_validation_report.md'

LANGUAGES = {
    'tr': 'Türkçe', 'en': 'English', 'ar': 'Arabic', 'be': 'Belarusian', 'bn': 'Bengali',
    'cs': 'Czech', 'da': 'Danish', 'de': 'German', 'el': 'Greek', 'es': 'Spanish',
    'fi': 'Finnish', 'fil': 'Filipino', 'fr': 'French', 'gu': 'Gujarati', 'hi': 'Hindi',
    'hr': 'Croatian', 'hu': 'Hungarian', 'id': 'Indonesian', 'it': 'Italian', 'ja': 'Japanese',
    'kn': 'Kannada', 'ko': 'Korean', 'ml': 'Malayalam', 'mr': 'Marathi', 'ms': 'Malay',
    'nl': 'Dutch', 'no': 'Norwegian', 'pa': 'Punjabi', 'pl': 'Polish', 'pt': 'Portuguese',
    'ro': 'Romanian', 'ru': 'Russian', 'sr': 'Serbian', 'sv': 'Swedish', 'ta': 'Tamil',
    'te': 'Telugu', 'th': 'Thai', 'uk': 'Ukrainian', 'vi': 'Vietnamese', 'zh': 'Chinese',
}

STRING_RE = re.compile(r"(['\"])([^'\"]+)\1\s*:\s*(['\"])((?:\\.|(?!\3).)*)\3", re.S)
PLACEHOLDER_RE = re.compile(r"\{[^{}]+\}")
PRESERVED = {
    'NICOTINE AWAY', 'Nicotine Away', 'AI Mentor', 'COPD', 'NVIDIA', 'Google',
    'Firebase', 'SQLite', 'Flutter', 'Dart', 'JSON', 'URL', 'API', 'OK',
}
EN_HINTS = re.compile(r"\b(the|and|or|your|you|with|from|this|that|test|start|save|settings|notifications|data|result|failed|warning|minutes|seconds|today|tomorrow|week|month|year)\b", re.I)
TR_HINTS = re.compile(r"\b(ve|veya|için|olan|olarak|veri|ayarlar|bildirimler|sonuç|başla|kaydet|bugün|yarın|hafta|ay|yıl|sigara|bırakma)\b", re.I)

def decode(s: str) -> str:
    return bytes(s, 'utf-8').decode('unicode_escape') if '\\' in s else s

def parse_maps(path: Path) -> dict[str, dict[str, str]]:
    text = path.read_text(encoding='utf-8')
    result: dict[str, dict[str, str]] = {}
    for m in re.finditer(r"['\"]([a-z]{2,3})['\"]\s*:\s*<String,\s*String>\s*\{(.*?)\n\s*\},", text, re.S):
        code, body = m.group(1), m.group(2)
        result[code] = {key: decode(value) for _, key, _, value in STRING_RE.findall(body)}
    return result

def parse_base(path: Path) -> dict[str, dict[str, str]]:
    text = path.read_text(encoding='utf-8')
    result = {}
    for code, marker in [('tr', '_tr'), ('en', '_en')]:
        start = text.find(marker)
        if start < 0: continue
        end = text.find('};', start)
        body = text[start:end if end >= 0 else None]
        result[code] = {key: decode(value) for _, key, _, value in STRING_RE.findall(body)}
    return result

def main():
    maps = {**parse_base(APP_TEXTS), **parse_maps(GENERATED)}
    source = {**maps.get('en', {}), **{k: v for k, v in maps.get('tr', {}).items() if k not in maps.get('en', {})}}
    report = {'language_count': len(LANGUAGES), 'parsed_language_count': len(maps), 'languages': {}, 'global': {}}
    all_keys = set(source)
    for code, name in LANGUAGES.items():
        values = maps.get(code, {})
        keys = set(values)
        missing = sorted(all_keys - keys)
        extra = sorted(keys - all_keys)
        empty = sorted(k for k in keys & all_keys if not values.get(k, '').strip())
        placeholder_errors = []
        for key in sorted(keys & all_keys):
            if sorted(PLACEHOLDER_RE.findall(source.get(key, ''))) != sorted(PLACEHOLDER_RE.findall(values.get(key, ''))):
                placeholder_errors.append(key)
        english_fallback = sorted(k for k in keys & all_keys if code not in ('en',) and values.get(k) == source.get(k) and values.get(k) and values.get(k) not in PRESERVED)
        turkish_mix = []
        english_mix = []
        for key, value in values.items():
            if not value or value in PRESERVED: continue
            if code == 'tr' and EN_HINTS.search(value) and not TR_HINTS.search(value): english_mix.append(key)
            elif code == 'en' and TR_HINTS.search(value) and not EN_HINTS.search(value): turkish_mix.append(key)
            elif code not in ('tr', 'en'):
                if value == maps.get('tr', {}).get(key) and re.search(r'[çğıİöşü]', value, re.I): turkish_mix.append(key)
        report['languages'][code] = {
            'name': name, 'keys': len(keys), 'missing': missing, 'extra': extra,
            'empty': empty, 'placeholder_errors': placeholder_errors,
            'english_fallback_candidates': english_fallback,
            'turkish_mix_candidates': turkish_mix,
            'english_hint_candidates': english_mix,
        }
    report['global'] = {
        'source_key_count': len(all_keys),
        'total_missing': sum(len(x['missing']) for x in report['languages'].values()),
        'total_extra': sum(len(x['extra']) for x in report['languages'].values()),
        'total_empty': sum(len(x['empty']) for x in report['languages'].values()),
        'total_placeholder_errors': sum(len(x['placeholder_errors']) for x in report['languages'].values()),
        'total_english_fallback_candidates': sum(len(x['english_fallback_candidates']) for x in report['languages'].values()),
        'total_turkish_mix_candidates': sum(len(x['turkish_mix_candidates']) for x in report['languages'].values()),
        'total_english_hint_candidates': sum(len(x['english_hint_candidates']) for x in report['languages'].values()),
    }
    OUT_JSON.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding='utf-8')
    lines = ['# Nicotine Away i18n Validation Report', '', f"- Parsed languages: **{len(maps)}/{len(LANGUAGES)}**", f"- Source keys: **{len(all_keys)}**", '']
    lines += ['| Dil | Anahtar | Eksik | Fazla | Boş | Placeholder | EN fallback adayı | TR karışım adayı |', '|---|---:|---:|---:|---:|---:|---:|---:|']
    for code, data in report['languages'].items():
        lines.append(f"| {code} ({data['name']}) | {data['keys']} | {len(data['missing'])} | {len(data['extra'])} | {len(data['empty'])} | {len(data['placeholder_errors'])} | {len(data['english_fallback_candidates'])} | {len(data['turkish_mix_candidates'])} |")
    lines += ['', '## Global checks', '', '| Kontrol | Sayı |', '|---|---:|']
    for k, v in report['global'].items(): lines.append(f'| {k} | {v} |')
    OUT_MD.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(json.dumps(report['global'], ensure_ascii=False, indent=2))
    for code, data in report['languages'].items():
        errors = {k: len(data[k]) for k in ('missing','extra','empty','placeholder_errors','english_fallback_candidates','turkish_mix_candidates','english_hint_candidates') if data[k]}
        if errors: print(code, errors)

if __name__ == '__main__': main()
