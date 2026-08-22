from pathlib import Path
import re

service = Path('/home/ubuntu/nikotin_away/lib/services/language_service.dart')
s = service.read_text(encoding='utf-8')
s = s.replace("    'hr': Locale('hr'),\n", "    'hr': Locale('hr'),\n    'ku': Locale('ku'),\n", 1)
s = s.replace("    'hr': 'Hrvatski',\n", "    'hr': 'Hrvatski',\n    'ku': 'Kurdî',\n", 1)
service.write_text(s, encoding='utf-8')

app = Path('/home/ubuntu/nikotin_away/lib/core/app_texts.dart')
at = app.read_text(encoding='utf-8')
m = re.search(r"  static const Map<String, String> _en = \{\n(.*?)\n  \};", at, re.S)
if not m:
    raise RuntimeError('English map not found')
body = m.group(1)
kurmanji = {
 'sleepScheduleTitle':'Demên Razanê û Rabûnê',
 'sleepScheduleDescription':'Demên razanê û rabûnê ji bo her rojê an rojên hilbijartî yên hefteyê bername bike.',
 'scheduleDaily':'Her roj',
 'scheduleByDay':'Rojan hilbijêre',
 'wakeAlarmTitle':'Alarmê rabûnê',
 'wakeAlarmBody':'Alarm dê di dema rabûna ku te hilbijartiye de lêxe.',
 'wakeAlarmEnabledTitle':'Alarmê rabûnê çalak bike',
 'wakeAlarmEnabledDescription':'Heke tu razî bî, alarm dê di dema hilbijartî de lêxe.',
 'sleepRoutineTonightTitle':'Dema razanê ya îşev',
 'sleepRoutineTonightBody':'Dema ku tu bi rastî dixwazî îşev razê hilbijêre.',
}
for key, value in kurmanji.items():
    body, n = re.subn(rf"(    '{re.escape(key)}':\s*)'((?:\\.|[^'])*)',", lambda x: x.group(1)+"'"+value.replace("'", "\\'")+"',", body, count=1)
    if n != 1:
        raise RuntimeError(f'missing English key {key}')
gen = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
gt = gen.read_text(encoding='utf-8')
if "  'ku': <String, String>{" not in gt:
    ku = "  'ku': <String, String>{\n" + body + "\n  },\n"
    if not gt.endswith('\n};\n'):
        raise RuntimeError('unexpected generated map ending')
    gt = gt[:-len('};\n')] + ku + '};\n'
gen.write_text(gt, encoding='utf-8')
print('added Kurdish ku / Kurmancî language map')
