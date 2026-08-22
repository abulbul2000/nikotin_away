from pathlib import Path
import re

p = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
s = p.read_text(encoding='utf-8')
keys = {
    'sleepRoutineReportSleepDuration': 'Sleep duration',
    'sleepRoutineReportEvidence': '{probes} sleep signals were processed overnight.',
    'sleepRoutineReportChargingProbes': 'Sleep signals captured while charging: {count}',
}
# Add the keys exactly once to every generated language map that lacks them.
block_re = re.compile(r"(?m)^(  '[^']+': <String, String>\{\n)(.*?)(?=^  \},$)", re.S)
def add(m):
    block = m.group(2)
    if "'sleepRoutineReportSleepDuration'" in block:
        return m.group(0)
    insertion = ''.join(f"    '{k}': '{v}',\n" for k, v in keys.items())
    anchor = "    'sleepRoutineReportTitle':"
    pos = block.find(anchor)
    if pos < 0:
        return m.group(0)
    line_end = block.find('\n', pos)
    new_block = block[:line_end+1] + insertion + block[line_end+1:]
    return m.group(1) + new_block + '  },'

s2 = block_re.sub(add, s)
p.write_text(s2, encoding='utf-8')
print('updated', s2.count("'sleepRoutineReportSleepDuration'"), 'generated entries')
