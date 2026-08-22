from pathlib import Path

path = Path('lib/core/generated_language_data.dart')
text = path.read_text(encoding='utf-8')
translations = {
    'de': 'Die tägliche Anzahl der Gesundheitstipps wurde aktualisiert.',
    'ar': 'تم تحديث عدد النصائح الصحية اليومية.',
    'fr': 'Le nombre quotidien de conseils santé a été mis à jour.',
    'es': 'Se actualizó la cantidad diaria de consejos de salud.',
    'pt': 'A quantidade diária de dicas de saúde foi atualizada.',
    'it': 'Il numero giornaliero di consigli sulla salute è stato aggiornato.',
    'pl': 'Zaktualizowano dzienną liczbę porad zdrowotnych.',
    'ru': 'Ежедневное количество советов о здоровье обновлено.',
    'ja': '毎日の健康アドバイス数を更新しました。',
    'zh': '每日健康建议数量已更新。',
    'ko': '일일 건강 조언 수가 업데이트되었습니다.',
    'hi': 'दैनिक स्वास्थ्य सुझावों की संख्या अपडेट कर दी गई है।',
    'bn': 'দৈনিক স্বাস্থ্য পরামর্শের সংখ্যা আপডেট করা হয়েছে।',
    'pa': 'ਰੋਜ਼ਾਨਾ ਸਿਹਤ ਸੁਝਾਵਾਂ ਦੀ ਗਿਣਤੀ ਅੱਪਡੇਟ ਕੀਤੀ ਗਈ ਹੈ।',
    'te': 'రోజువారీ ఆరోగ్య సూచనల సంఖ్య నవీకరించబడింది.',
    'mr': 'दररोजच्या आरोग्य टिपांची संख्या अपडेट केली आहे.',
    'ta': 'தினசரி சுகாதார ஆலோசனைகளின் எண்ணிக்கை புதுப்பிக்கப்பட்டது.',
    'gu': 'દૈનિક આરોગ્ય સૂચનોની સંખ્યા અપડેટ કરવામાં આવી છે.',
    'kn': 'ದೈನಂದಿನ ಆರೋಗ್ಯ ಸಲಹೆಗಳ ಸಂಖ್ಯೆಯನ್ನು ನವೀಕರಿಸಲಾಗಿದೆ.',
    'ml': 'ദൈനംദിന ആരോഗ്യ നിർദ്ദേശങ്ങളുടെ എണ്ണം അപ്ഡേറ്റ് ചെയ്തു.',
    'th': 'อัปเดตจำนวนคำแนะนำด้านสุขภาพรายวันแล้ว',
    'vi': 'Số lượng lời khuyên sức khỏe hằng ngày đã được cập nhật.',
    'id': 'Jumlah tips kesehatan harian telah diperbarui.',
    'ms': 'Bilangan tip kesihatan harian telah dikemas kini.',
    'fil': 'Na-update ang bilang ng mga pang-araw-araw na payong pangkalusugan.',
    'uk': 'Щоденну кількість порад щодо здоров’я оновлено.',
    'ro': 'Numărul zilnic de sfaturi pentru sănătate a fost actualizat.',
    'el': 'Ο ημερήσιος αριθμός συμβουλών υγείας ενημερώθηκε.',
    'hu': 'A napi egészségügyi tippek száma frissítve.',
    'cs': 'Denní počet zdravotních tipů byl aktualizován.',
    'sv': 'Det dagliga antalet hälsotips har uppdaterats.',
    'da': 'Det daglige antal sundhedsråd er blevet opdateret.',
    'no': 'Det daglige antallet helseråd er oppdatert.',
    'fi': 'Päivittäisten terveysvinkkien määrä on päivitetty.',
    'nl': 'Het dagelijkse aantal gezondheidstips is bijgewerkt.',
    'be': 'Штодзённая колькасць парад па здароўі абноўлена.',
    'sr': 'Дневни број здравствених савета је ажуриран.',
    'hr': 'Dnevni broj zdravstvenih savjeta ažuriran je.',
}

lines = text.splitlines(keepends=True)
current = None
seen = set()
out = []
for line in lines:
    if line.startswith("  '") and line.endswith("': <String, String>{\n"):
        current = line.split("'")[1]
    out.append(line)
    if current in translations and "'aiChatActionAppliedMedication':" in line:
        newline = "\n" if line.endswith("\n") else ""
        out.append(f"    'aiChatActionAppliedHealthTipCount': '{translations[current]}',{newline}")
        seen.add(current)

missing = set(translations) - seen
if missing:
    raise SystemExit(f'missing language maps: {sorted(missing)}')
if text.count("'aiChatActionAppliedHealthTipCount':") != 0:
    raise SystemExit('key already exists; aborting to avoid duplication')
path.write_text(''.join(out), encoding='utf-8')
print(f'added {len(seen)} translations')
