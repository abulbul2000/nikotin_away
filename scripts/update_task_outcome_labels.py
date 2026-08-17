from pathlib import Path
import json
import re

path = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
text = path.read_text(encoding='utf-8')

labels = {
    'de': ('Nein — Erfolgreich', 'Ja — Nicht erfolgreich'),
    'ar': ('لم أدخّن — ناجح', 'دخّنت — غير ناجح'),
    'fr': ('Je n’ai pas fumé — Réussi', 'J’ai fumé — Échec'),
    'es': ('No fumé — Éxito', 'Fumé — No logrado'),
    'pt': ('Não fumei — Sucesso', 'Fumei — Não concluído'),
    'it': ('Non ho fumato — Riuscito', 'Ho fumato — Non riuscito'),
    'pl': ('Nie paliłem — Sukces', 'Paliłem — Nieudane'),
    'ru': ('Не курил — Успешно', 'Курил — Неуспешно'),
    'ja': ('吸わなかった — 成功', '吸った — 失敗'),
    'zh': ('没有吸烟 — 成功', '吸烟了 — 未成功'),
    'ko': ('피우지 않았어요 — 성공', '피웠어요 — 실패'),
    'hi': ('नहीं पी — सफल', 'पी — असफल'),
    'bn': ('ধূমপান করিনি — সফল', 'ধূমপান করেছি — ব্যর্থ'),
    'pa': ('ਨਹੀਂ ਪੀਤੀ — ਸਫਲ', 'ਪੀਤੀ — ਅਸਫਲ'),
    'te': ('పొగ తాగలేదు — విజయవంతం', 'పొగ తాగాను — విఫలమైంది'),
    'mr': ('धूम्रपान केले नाही — यशस्वी', 'धूम्रपान केले — अयशस्वी'),
    'ta': ('புகைபிடிக்கவில்லை — வெற்றி', 'புகைபிடித்தேன் — தோல்வி'),
    'gu': ('ધૂમ્રપાન કર્યું નથી — સફળ', 'ધૂમ્રપાન કર્યું — નિષ્ફળ'),
    'kn': ('ಧೂಮಪಾನ ಮಾಡಲಿಲ್ಲ — ಯಶಸ್ವಿ', 'ಧೂಮಪಾನ ಮಾಡಿದೆ — ವಿಫಲ'),
    'ml': ('പുകവലിച്ചില്ല — വിജയിച്ചു', 'പുകവലിച്ചു — പരാജയം'),
    'th': ('ไม่ได้สูบ — สำเร็จ', 'สูบแล้ว — ไม่สำเร็จ'),
    'vi': ('Không hút — Thành công', 'Đã hút — Chưa thành công'),
    'id': ('Tidak merokok — Berhasil', 'Merokok — Tidak berhasil'),
    'ms': ('Tidak merokok — Berjaya', 'Merokok — Tidak berjaya'),
    'fil': ('Hindi nanigarilyo — Tagumpay', 'Nanigarilyo — Hindi nagtagumpay'),
    'uk': ('Не курив — Успішно', 'Курив — Неуспішно'),
    'ro': ('Nu am fumat — Reușit', 'Am fumat — Nereușit'),
    'el': ('Δεν κάπνισα — Επιτυχία', 'Κάπνισα — Αποτυχία'),
    'hu': ('Nem dohányoztam — Sikeres', 'Dohányoztam — Sikertelen'),
    'cs': ('Nekouřil jsem — Úspěch', 'Kouřil jsem — Neúspěch'),
    'sv': ('Jag rökte inte — Lyckades', 'Jag rökte — Misslyckades'),
    'da': ('Jeg røg ikke — Gennemført', 'Jeg røg — Ikke gennemført'),
    'no': ('Jeg røykte ikke — Vellykket', 'Jeg røykte — Ikke vellykket'),
    'fi': ('En polttanut — Onnistui', 'Poltin — Ei onnistunut'),
    'nl': ('Niet gerookt — Gelukt', 'Gerookt — Niet gelukt'),
    'be': ('Не курыў — Паспяхова', 'Курыў — Няўдала'),
    'sr': ('Nisam pušio — Uspešno', 'Pušio sam — Neuspešno'),
    'hr': ('Nisam pušio — Uspješno', 'Pušio sam — Neuspješno'),
}

for code, (no_label, yes_label) in labels.items():
    block_match = re.search(
        rf"(?m)^  '{re.escape(code)}': <String, String>\{{(?P<body>.*?)(?=^  '[a-z]+': <String, String>\{{|^\}};)",
        text,
        re.S,
    )
    if not block_match:
        raise SystemExit(f'missing language block: {code}')
    body = block_match.group('body')
    body, no_count = re.subn(
        r"(?m)^    'taskConfirmNoLabel': '[^']*',",
        "    'taskConfirmNoLabel': " + json.dumps(no_label, ensure_ascii=False) + ',',
        body,
        count=1,
    )
    body, yes_count = re.subn(
        r"(?m)^    'taskConfirmYesLabel': '[^']*',",
        "    'taskConfirmYesLabel': " + json.dumps(yes_label, ensure_ascii=False) + ',',
        body,
        count=1,
    )
    if no_count != 1 or yes_count != 1:
        raise SystemExit(f'missing labels in language block: {code}')
    text = text[:block_match.start('body')] + body + text[block_match.end('body'):]

path.write_text(text, encoding='utf-8')
