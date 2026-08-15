#!/usr/bin/env python3
"""Adds new report keys to every language block in generated_language_data.dart."""

import re

PATH = "lib/core/generated_language_data.dart"

with open(PATH, encoding="utf-8") as f:
    content = f.read()

new_keys = {
    "reportsAvertedCigarettes": {
        "de": "Geschätzte nicht gerauchte Zigaretten",
        "ar": "السجائر التي لم تُعدَّ تدخينها (تقديرية)",
        "fr": "Cigarettes non fumées estimées",
        "es": "Cigarrillos no fumados estimados",
        "pt": "Cigarros estimados não fumados",
        "it": "Sigarette non fumate stimate",
        "pl": "Szacowane niezapalone papierosy",
        "ru": "Ocenenno ne vykurennye sigarety",
        "ja": "吸わなかったと推定されるタバコ本数",
        "zh": "估计未吸的烟数量",
        "ko": "흡연하지 않았다고 추정되는 담배 수",
        "hi": "Anumanit nahi piye gaye sigare",
        "bn": "Anumanik na khawa sigaret",
        "pa": "Anumanit na piyan sigrean",
        "te": "Postani veyyani sigaretilu (anumanam)",
        "mr": "Andazit kelele na pitalele sigarettiche",
        "ta": "Pidikkatha endru anumanikkirra sigarettukal",
        "gu": "Anumanit na pidhayel sigaret",
        "kn": "Sediyilla endu anumanisida sigarettigalu",
        "ml": "Pukaiyatha ennu karuthunna sigarettukal",
        "th": "Buhrri sigaret thi yang mai sut (praman)",
        "vi": "So thuoc da tinh la khong hut",
        "id": "Rokok yang diperkirakan tidak dihisap",
        "ms": "Rokok dianggarkan tidak dihisap",
    },
    "reportsSmokingTimePattern": {
        "de": "Zeitverteilung des Rauchens",
        "ar": "توزيع وقت التدخين",
        "fr": "Répartition des moments de fumage",
        "es": "Distribución del tiempo de fumar",
        "pt": "Distribuição do horário de fumar",
        "it": "Distribuzione oraria del fumo",
        "pl": "Rozkład czasu palenia",
        "ru": "Raspredelenie vremeni kureniya",
        "ja": "喫煙時間帯の分布",
        "zh": "吸烟时间分布",
        "ko": "흡연 시간 분포",
        "hi": "Smoking samay vitran",
        "bn": "Dhumpaner somoy bintaron",
        "pa": "Dhumrapan samay vand",
        "te": "Dumrida vyapti",
        "mr": "Dhumrapan velyache vitaran",
        "ta": "Pukai pitikkum neravigalin pirivu",
        "gu": "Dhumrapan samay vitran",
        "kn": "Dhumrapana samaya vitarane",
        "ml": "Pukaiyil niramayude vitaranam",
        "th": "Kan jad jang wa la pi buhrri",
        "vi": "Phan bo thoi gian hut thuoc",
        "id": "Pola waktu merokok",
        "ms": "Taburan masa merokok",
    },
    "reportsNoDataYet": {
        "de": "Noch nicht genug Daten",
        "ar": "لا توجد بيانات كافية بعد",
        "fr": "Pas encore assez de données",
        "es": "Aún no hay suficientes datos",
        "pt": "Ainda não há dados suficientes",
        "it": "Non ci sono ancora dati sufficienti",
        "pl": "Jeszcze za mało danych",
        "ru": "Pokha nedostatochno dannykh",
        "ja": "まだデータが不足しています",
        "zh": "数据还不足",
        "ko": "아직 데이터가 부족합니다",
        "hi": "Abhi parapt data nahin",
        "bn": "Ekhono parjapto data nei",
        "pa": "Hune kafi data nahin",
        "te": "Ivati sari samapt samakhyalu ledu",
        "mr": "Abhi puresa data nahin",
        "ta": "Innum potumana tharavukal illai",
        "gu": "Haje parapt data nathi",
        "kn": "Ivuvarigu salu dattamshagalu illa",
        "ml": "Innu padhyamanam data illa",
        "th": "Yang mai mi khomul phriang",
        "vi": "Chua du du lieu",
        "id": "Belum ada data yang cukup",
        "ms": "Belum cukup data",
    },
    "reportsPartMorning": {
        "de": "Morgen (05-10)",
        "ar": "الصباح (05-10)",
        "fr": "Matin (05-10)",
        "es": "Mañana (05-10)",
        "pt": "Manhã (05-10)",
        "it": "Mattina (05-10)",
        "pl": "Rano (05-10)",
        "ru": "Utro (05-10)",
        "ja": "朝 (05-10)",
        "zh": "上午 (05-10)",
        "ko": "오전 (05-10)",
        "hi": "Subah (05-10)",
        "bn": "Shokal (05-10)",
        "pa": "Subah (05-10)",
        "te": "Udayam (05-10)",
        "mr": "Sakal (05-10)",
        "ta": "Kaalai (05-10)",
        "gu": "Savare (05-10)",
        "kn": "Beliggane (05-10)",
        "ml": "Prabhatham (05-10)",
        "th": "Chao (05-10)",
        "vi": "Sang (05-10)",
        "id": "Pagi (05-10)",
        "ms": "Pagi (05-10)",
    },
    "reportsPartMidday": {
        "de": "Mittag (10-13)",
        "ar": "الظهر (10-13)",
        "fr": "Midi (10-13)",
        "es": "Mediodía (10-13)",
        "pt": "Meio-dia (10-13)",
        "it": "Mezzogiorno (10-13)",
        "pl": "Południe (10-13)",
        "ru": "Polden (10-13)",
        "ja": "正午 (10-13)",
        "zh": "中午 (10-13)",
        "ko": "정오 (10-13)",
        "hi": "Dopahar (10-13)",
        "bn": "Dupur (10-13)",
        "pa": "Dophar (10-13)",
        "te": "Madhyanam (10-13)",
        "mr": "Dupar (10-13)",
        "ta": "Mathiyam (10-13)",
        "gu": "Dupar (10-13)",
        "kn": "Madhyahna (10-13)",
        "ml": "Madhyahnam (10-13)",
        "th": "Thiang (10-13)",
        "vi": "Trua (10-13)",
        "id": "Siang (10-13)",
        "ms": "Tengah hari (10-13)",
    },
    "reportsPartAfternoon": {
        "de": "Nachmittag (13-17)",
        "ar": "بعد الظهر (13-17)",
        "fr": "Après-midi (13-17)",
        "es": "Tarde (13-17)",
        "pt": "Tarde (13-17)",
        "it": "Pomeriggio (13-17)",
        "pl": "Popołudnie (13-17)",
        "ru": "Dnevnoe vremya (13-17)",
        "ja": "午後 (13-17)",
        "zh": "下午 (13-17)",
        "ko": "오후 (13-17)",
        "hi": "Dopahar baad (13-17)",
        "bn": "Dupur por (13-17)",
        "pa": "Dophar ton baad (13-17)",
        "te": "Madhyahnam tarvata (13-17)",
        "mr": "Duparchi ved (13-17)",
        "ta": "Mathiyam pirkku (13-17)",
        "gu": "Dupar pachi (13-17)",
        "kn": "Madhyahnanada nantara (13-17)",
        "ml": "Uchakkulla samayam (13-17)",
        "th": "Bai (13-17)",
        "vi": "Chieu (13-17)",
        "id": "Sore (13-17)",
        "ms": "Petang (13-17)",
    },
    "reportsPartEvening": {
        "de": "Abend (17-22)",
        "ar": "المساء (17-22)",
        "fr": "Soir (17-22)",
        "es": "Anochecer (17-22)",
        "pt": "Noite (17-22)",
        "it": "Sera (17-22)",
        "pl": "Wieczór (17-22)",
        "ru": "Vecher (17-22)",
        "ja": "夕方 (17-22)",
        "zh": "傍晚 (17-22)",
        "ko": "저녁 (17-22)",
        "hi": "Shaam (17-22)",
        "bn": "Shondha (17-22)",
        "pa": "Sham (17-22)",
        "te": "Sandyakalam (17-22)",
        "mr": "Sanjh (17-22)",
        "ta": "Maalai (17-22)",
        "gu": "Sanjh (17-22)",
        "kn": "Sanje (17-22)",
        "ml": "Vayikunnneram (17-22)",
        "th": "Yen (17-22)",
        "vi": "Toi (17-22)",
        "id": "Petang (17-22)",
        "ms": "Petang (17-22)",
    },
    "reportsPartNight": {
        "de": "Nacht (22-05)",
        "ar": "الليل (22-05)",
        "fr": "Nuit (22-05)",
        "es": "Noche (22-05)",
        "pt": "Madrugada (22-05)",
        "it": "Notte (22-05)",
        "pl": "Noc (22-05)",
        "ru": "Noch (22-05)",
        "ja": "夜 (22-05)",
        "zh": "夜间 (22-05)",
        "ko": "밤 (22-05)",
        "hi": "Raat (22-05)",
        "bn": "Rat (22-05)",
        "pa": "Raat (22-05)",
        "te": "Ratri (22-05)",
        "mr": "Ratri (22-05)",
        "ta": "Iravu (22-05)",
        "gu": "Raat (22-05)",
        "kn": "Ratri (22-05)",
        "ml": "Rathri (22-05)",
        "th": "Klang khuen (22-05)",
        "vi": "Dem (22-05)",
        "id": "Malam (22-05)",
        "ms": "Malam (22-05)",
    },
    "reportsDisclaimer": {
        "de": "Dieser Bericht enthält Schätzungen auf Basis Ihrer Aufzeichnungen; er ist keine medizinische Beurteilung oder Diagnose. Konsultieren Sie für persönliche Gesundheitsentscheidungen Ihren Arzt.",
        "ar": "يحتوي هذا التقرير على تقديرات مبنية على سجلاتك؛ ولا يعد تقييماً أو تشخيصاً طبياً. استشر طبيبك لقراراتك الصحية الشخصية.",
        "fr": "Ce rapport contient des estimations basées sur vos enregistrements ; il ne constitue pas une évaluation ou un diagnostic médical. Consultez votre médecin pour vos décisions de santé personnelles.",
        "es": "Este informe contiene estimaciones basadas en sus registros; no es una evaluación ni diagnóstico médico. Consulte a su médico para decisiones de salud personales.",
        "pt": "Este relatório contém estimativas baseadas nos seus registos; não é uma avaliação ou diagnóstico médico. Consulte o seu médico para decisões de saúde pessoais.",
        "it": "Questo rapporto contiene stime basate sui tuoi registri; non è una valutazione o diagnosi medica. Consulta il tuo medico per decisioni di salute personali.",
        "pl": "Ten raport zawiera szacunki oparte na Twoich zapisach; nie jest oceną ani diagnozą medyczną. Skonsultuj się z lekarzem w sprawach osobistych decyzji zdrowotnych.",
        "ru": "Etot otchet soderzhit otsenki na osnove vashikh zapisei; on ne yavlyaetsya meditsinskim zaklyucheniem ili diagnozom. Prokonsultiruytes s vrachom.",
        "ja": "このレポートは記録に基づく推定値を含みます。医学的評価や診断ではありません。個人の健康に関する決定は医師にご相談ください。",
        "zh": "本报告包含基于您记录的估算信息，不是医学评估或诊断。个人健康决定请咨询医生。",
        "ko": "이 보고서는 기록에 기반한 추정치를 포함하며 의학적 평가나 진단이 아닙니다. 개인적인 건강 결정은 의사와 상담하십시오.",
        "hi": "Yeh report aapke records par aadharit anuman hai; yeh chikitsa mulyankan ya nidan nahin hai. Vyaktigat svasthya nirnayon ke lie apne chikitsak se paramarsh karen.",
        "bn": "Ei riporte apanar rekard onujayi anumanik tottho achhe; eta chikitsa mulyayan ba rog nirnay noy. Bektigoto sastho siddhantek niye apnar daktarke poramorsho korun.",
        "pa": "Eh report tuhadde records utte aadharit anuman han; eh chikitsak mulankan ya rog da varnan nahi hai. Jati swasthfa faislyan layi apne doctor nu pucho.",
        "te": "I report mii records paruna anumanalu; idi vaidyaka parisilana ledu. Vyaktigata arogya nirnayal kosam vaidyuni sampradinchandi.",
        "mr": "He aharaval aaplya nondvar adharit andaj ahe; te vaidyakiya mulakhyan kinvh nidhan nahi. Vyaktigat arogya nirnyasathi aaplya doktorashi salh karo.",
        "ta": "Intha arivu unkal parivankalin adipparaiyil ulla vaigal; idi maruththuva muthalaiyallathu nirnayam allathu. Thanippaththa maruththuva mudivugaukkaaga unkal maruththuvarinai aalochikkai.",
        "gu": "Aa report tamara records par aadharit anuman chhe; aa charikitsakiye mulyankan ke roganidhan nathi. Vyaktigat arogya nirnayo mate tamara doctor ne puchho.",
        "kn": "I report nimma records adharisida anumanagalu; idu vaidyakiya mulamadyana athava nidanavalla. Vyaktigata arogya nirnayagaluge vaidyaruge samparkisi.",
        "ml": "I report ninte records adishttama anumanangal; idh vaidyika mulyankanallanu. Vyaktigatha arogya theerumanangalkku doctorine sampradhikkuka.",
        "th": "Rapangan ni mi khomul anuman thi ang ong atrra khun; mi chai karan winaicchai thang kan paet. Porukha paet khong than per son karn chao tha nai.",
        "vi": "Bao cao nay chua cac uoc tinh dua tren ho so cua ban; khong phai la danh gia hay chan doan y te. Hay tham khao y bac si cho cac quyet dinh suc khoe ca nhan.",
        "id": "Laporan ini berisi perkiraan berdasarkan catatan Anda; bukan penilaian atau diagnosis medis. Konsultasikan dengan dokter untuk keputusan kesehatan pribadi.",
        "ms": "Laporan ini mengandungi anggaran berdasarkan rekod anda; ia bukan penilaian atau diagnosis perubatan. Rujuk doktor anda untuk keputusan kesihatan peribadi.",
    },
}

en_fallback = {
    "reportsAvertedCigarettes": "Estimated cigarettes not smoked",
    "reportsSmokingTimePattern": "Smoking time distribution",
    "reportsNoDataYet": "Not enough data yet",
    "reportsPartMorning": "Morning (05-10)",
    "reportsPartMidday": "Midday (10-13)",
    "reportsPartAfternoon": "Afternoon (13-17)",
    "reportsPartEvening": "Evening (17-22)",
    "reportsPartNight": "Night (22-05)",
    "reportsDisclaimer": "This report contains estimates based on your records; it is not a medical assessment or diagnosis. Consult your doctor for personal health decisions.",
}

lang_codes = [
    "de", "ar", "fr", "es", "pt", "it", "pl", "ru", "ja", "zh", "ko",
    "hi", "bn", "pa", "te", "mr", "ta", "gu", "kn", "ml", "th", "vi", "id", "ms",
]


def format_entry(key, value):
    escaped = value.replace("\\", "\\\\").replace("'", "\\'")
    if len(value) > 75:
        return "    '{key}':\n        '{value}',".format(key=key, value=escaped)
    return "    '{key}': '{value}',".format(key=key, value=escaped)


count = 0
for lang in lang_codes:
    pattern = re.compile(
        r"^  '" + lang + r"': <String, String>\{", re.MULTILINE
    )
    match = pattern.search(content)
    if not match:
        print("WARN: lang block {} not found".format(lang))
        continue

    depth = 1
    pos = match.end()
    while depth > 0 and pos < len(content):
        c = content[pos]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
        pos += 1
    insert_at = pos - 1

    lines = []
    for key in sorted(new_keys.keys()):
        value = new_keys[key].get(lang, en_fallback.get(key, ""))
        lines.append(format_entry(key, value))

    insertion = "\n" + "\n".join(lines) + "\n  "
    content = content[:insert_at] + insertion + content[insert_at:]
    count += 1
    print("Added keys to {}".format(lang))

with open(PATH, "w", encoding="utf-8") as f:
    f.write(content)

print("Done. Updated {} language blocks with 9 new keys each.".format(count))
