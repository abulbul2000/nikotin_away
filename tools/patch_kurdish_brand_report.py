from pathlib import Path
import re

p = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
s = p.read_text(encoding='utf-8')
values = {
    'ku': {
        'appName': 'NICOTINE AWAY',
        'appTagline': 'Rêberê te yê kesane ji bo devjêberdana cixarekişandinê',
        'sleepRoutineReportSleepDuration': 'Dirêjahiya xewê',
        'sleepRoutineReportEvidence': 'Di şevê de {probes} nîşanên xewê hatin pêvajokirin.',
        'sleepRoutineReportChargingProbes': 'Nîşanên xewê yên di dema şarjê de hatin girtin: {count}',
    },
    'ku-arab': {
        'appName': 'نیکۆتین ئەوەی',
        'appTagline': 'ڕێبەری تایبەتی تۆ بۆ وازهێنان لە جگەرەکێشان',
        'sleepRoutineReportSleepDuration': 'ماوەی خەوتن',
        'sleepRoutineReportEvidence': 'لە شەودا {probes} نیشانەی خەوتن پڕۆسە کرا.',
        'sleepRoutineReportChargingProbes': 'نیشانەکانی خەوتن لە کاتی شەحنکردندا: {count}',
    },
}
for code, replacements in values.items():
    m = re.search(rf"  '{re.escape(code)}': <String, String>{{\n(.*?)\n  }},", s, re.S)
    if not m:
        raise RuntimeError(code)
    block = m.group(1)
    for key, value in replacements.items():
        escaped = value.replace('\\', '\\\\').replace("'", "\\'")
        pattern = rf"(^    '{re.escape(key)}':\s*)'((?:\\.|[^'])*)',\s*$"
        block, count = re.subn(pattern, rf"\g<1>'{escaped}',", block, flags=re.M)
        if count != 1:
            raise RuntimeError(f'{code}:{key} replacements={count}')
    s = s[:m.start(1)] + block + s[m.end(1):]
p.write_text(s, encoding='utf-8')
