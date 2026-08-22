from pathlib import Path
import re

translations = {
 'tr': {'sleepScheduleTitle':'Uyku ve Uyanma Saatleri','sleepScheduleDescription':'Her gün veya haftanın günlerine göre uyku ve uyanma saatlerini planla.','scheduleDaily':'Her gün','scheduleByDay':'Gün seçerek','wakeAlarmTitle':'Uyandırma alarmı','wakeAlarmBody':'Belirlediğin uyanma saatinde seni uyandırmak için alarm çalacak.','wakeAlarmEnabledTitle':'Uyanma alarmını etkinleştir','wakeAlarmEnabledDescription':'Onaylarsan alarm, seçtiğin uyanma saatinde çalar.','sleepRoutineTonightTitle':'Bu gece uyku saatin','sleepRoutineTonightBody':'Bu gece gerçekten uyumayı planladığın saati seç.'},
 'en': {'sleepScheduleTitle':'Sleep and Wake Times','sleepScheduleDescription':'Plan sleep and wake times for every day or for selected days of the week.','scheduleDaily':'Every day','scheduleByDay':'Select days','wakeAlarmTitle':'Wake-up alarm','wakeAlarmBody':'The alarm will ring at your chosen wake-up time.','wakeAlarmEnabledTitle':'Enable wake-up alarm','wakeAlarmEnabledDescription':'If you agree, the alarm will ring at your selected wake-up time.','sleepRoutineTonightTitle':'Tonight’s sleep time','sleepRoutineTonightBody':'Choose the time you actually plan to go to sleep tonight.'},
 'de': {'sleepScheduleTitle':'Schlaf- und Aufstehzeiten','sleepScheduleDescription':'Plane Schlaf- und Aufstehzeiten für jeden Tag oder ausgewählte Wochentage.','scheduleDaily':'Jeden Tag','scheduleByDay':'Tage auswählen','wakeAlarmTitle':'Weckalarm','wakeAlarmBody':'Der Alarm klingelt zu deiner gewählten Aufstehzeit.','wakeAlarmEnabledTitle':'Weckalarm aktivieren','wakeAlarmEnabledDescription':'Wenn du zustimmst, klingelt der Alarm zur ausgewählten Aufstehzeit.','sleepRoutineTonightTitle':'Schlafenszeit heute Nacht','sleepRoutineTonightBody':'Wähle die Zeit, zu der du heute wirklich schlafen gehen möchtest.'},
 'ar': {'sleepScheduleTitle':'أوقات النوم والاستيقاظ','sleepScheduleDescription':'خطط لأوقات النوم والاستيقاظ لكل يوم أو لأيام محددة من الأسبوع.','scheduleDaily':'كل يوم','scheduleByDay':'اختيار الأيام','wakeAlarmTitle':'منبه الاستيقاظ','wakeAlarmBody':'سيرن المنبه في وقت الاستيقاظ الذي اخترته.','wakeAlarmEnabledTitle':'تفعيل منبه الاستيقاظ','wakeAlarmEnabledDescription':'عند الموافقة، سيرن المنبه في وقت الاستيقاظ المحدد.','sleepRoutineTonightTitle':'وقت نوم الليلة','sleepRoutineTonightBody':'اختر الوقت الذي تخطط فعليًا للنوم فيه الليلة.'},
 'fr': {'sleepScheduleTitle':'Heures de sommeil et de réveil','sleepScheduleDescription':'Planifiez vos heures de sommeil et de réveil pour chaque jour ou pour certains jours.','scheduleDaily':'Tous les jours','scheduleByDay':'Choisir les jours','wakeAlarmTitle':'Alarme de réveil','wakeAlarmBody':'L’alarme sonnera à l’heure de réveil choisie.','wakeAlarmEnabledTitle':'Activer l’alarme de réveil','wakeAlarmEnabledDescription':'Avec votre accord, l’alarme sonnera à l’heure sélectionnée.','sleepRoutineTonightTitle':'Heure de sommeil ce soir','sleepRoutineTonightBody':'Choisissez l’heure à laquelle vous prévoyez réellement de dormir ce soir.'},
 'es': {'sleepScheduleTitle':'Horarios de sueño y despertar','sleepScheduleDescription':'Planifica las horas de sueño y despertar para cada día o para días concretos.','scheduleDaily':'Todos los días','scheduleByDay':'Elegir días','wakeAlarmTitle':'Alarma de despertar','wakeAlarmBody':'La alarma sonará a la hora de despertar que elijas.','wakeAlarmEnabledTitle':'Activar alarma de despertar','wakeAlarmEnabledDescription':'Si aceptas, la alarma sonará a la hora seleccionada.','sleepRoutineTonightTitle':'Hora de dormir esta noche','sleepRoutineTonightBody':'Elige la hora a la que realmente piensas dormir esta noche.'},
 'pt': {'sleepScheduleTitle':'Horários de sono e despertar','sleepScheduleDescription':'Planeje os horários de sono e despertar para todos os dias ou dias escolhidos.','scheduleDaily':'Todos os dias','scheduleByDay':'Escolher dias','wakeAlarmTitle':'Alarme de despertar','wakeAlarmBody':'O alarme tocará no horário de despertar escolhido.','wakeAlarmEnabledTitle':'Ativar alarme de despertar','wakeAlarmEnabledDescription':'Se você aceitar, o alarme tocará no horário selecionado.','sleepRoutineTonightTitle':'Horário de dormir hoje','sleepRoutineTonightBody':'Escolha a hora em que realmente pretende dormir hoje.'},
 'it': {'sleepScheduleTitle':'Orari di sonno e risveglio','sleepScheduleDescription':'Pianifica gli orari di sonno e risveglio per ogni giorno o per giorni scelti.','scheduleDaily':'Ogni giorno','scheduleByDay':'Scegli i giorni','wakeAlarmTitle':'Sveglia','wakeAlarmBody':'La sveglia suonerà all’orario di risveglio scelto.','wakeAlarmEnabledTitle':'Attiva la sveglia','wakeAlarmEnabledDescription':'Se accetti, la sveglia suonerà all’orario selezionato.','sleepRoutineTonightTitle':'Orario di sonno di stasera','sleepRoutineTonightBody':'Scegli l’ora in cui prevedi davvero di dormire stasera.'},
 'pl': {'sleepScheduleTitle':'Godziny snu i pobudki','sleepScheduleDescription':'Zaplanuj godziny snu i pobudki na każdy dzień lub wybrane dni tygodnia.','scheduleDaily':'Codziennie','scheduleByDay':'Wybierz dni','wakeAlarmTitle':'Budzik','wakeAlarmBody':'Budzik zadzwoni o wybranej godzinie pobudki.','wakeAlarmEnabledTitle':'Włącz budzik','wakeAlarmEnabledDescription':'Po wyrażeniu zgody budzik zadzwoni o wybranej godzinie.','sleepRoutineTonightTitle':'Dzisiejsza pora snu','sleepRoutineTonightBody':'Wybierz godzinę, o której naprawdę planujesz dziś zasnąć.'},
 'ru': {'sleepScheduleTitle':'Время сна и пробуждения','sleepScheduleDescription':'Настройте время сна и пробуждения на каждый день или на выбранные дни недели.','scheduleDaily':'Каждый день','scheduleByDay':'Выбрать дни','wakeAlarmTitle':'Будильник','wakeAlarmBody':'Будильник прозвонит в выбранное время пробуждения.','wakeAlarmEnabledTitle':'Включить будильник','wakeAlarmEnabledDescription':'Если вы согласны, будильник прозвонит в выбранное время.','sleepRoutineTonightTitle':'Время сна сегодня','sleepRoutineTonightBody':'Выберите время, когда вы действительно планируете лечь спать сегодня.'},
 'ja': {'sleepScheduleTitle':'睡眠と起床の時間','sleepScheduleDescription':'毎日または曜日ごとに睡眠時間と起床時間を設定します。','scheduleDaily':'毎日','scheduleByDay':'曜日を選択','wakeAlarmTitle':'起床アラーム','wakeAlarmBody':'選択した起床時刻にアラームが鳴ります。','wakeAlarmEnabledTitle':'起床アラームを有効にする','wakeAlarmEnabledDescription':'同意すると、選択した時刻にアラームが鳴ります。','sleepRoutineTonightTitle':'今夜の就寝時刻','sleepRoutineTonightBody':'今夜実際に寝る予定の時刻を選択してください。'},
 'zh': {'sleepScheduleTitle':'睡眠和起床时间','sleepScheduleDescription':'为每天或指定的星期几安排睡眠和起床时间。','scheduleDaily':'每天','scheduleByDay':'选择日期','wakeAlarmTitle':'起床闹钟','wakeAlarmBody':'闹钟会在你选择的起床时间响起。','wakeAlarmEnabledTitle':'启用起床闹钟','wakeAlarmEnabledDescription':'同意后，闹钟会在所选时间响起。','sleepRoutineTonightTitle':'今晚的睡觉时间','sleepRoutineTonightBody':'选择你今晚实际计划入睡的时间。'},
}
# Remaining supported languages use explicit English until their full language pack is reviewed.
for code in ['ko','hi','bn','pa','te','mr','ta','gu','kn','ml','th','vi','id','ms','fil','uk','ro','el','hu','cs','sv','da','no','fi','nl','be','sr','hr']:
    translations[code] = translations['en']

def entry_block(values):
    return ''.join(f"    '{k}': {v!r},\n" for k,v in values.items()).replace("'", "'")

def add_to_map(text, header, values):
    start = text.find(header)
    if start < 0:
        return text
    body_start = start + len(header)
    next_map = re.search(r"^  (?:static const Map<String, String> _[a-z]+|'[a-z]{2,3}')(?:: <String, String>)? \\{", text[body_start:], re.MULTILINE)
    end = body_start + next_map.start() if next_map else len(text)
    block = text[body_start:end]
    missing = {k: v for k, v in values.items() if f"'{k}':" not in block}
    if not missing:
        return text
    return text[:body_start] + entry_block(missing) + text[body_start:]

app = Path('/home/ubuntu/nikotin_away/lib/core/app_texts.dart')
text = app.read_text(encoding='utf-8')
text = add_to_map(text, "  static const Map<String, String> _tr = {\n", translations['tr'])
text = add_to_map(text, "  static const Map<String, String> _en = {\n", translations['en'])
app.write_text(text, encoding='utf-8')

gen = Path('/home/ubuntu/nikotin_away/lib/core/generated_language_data.dart')
text = gen.read_text(encoding='utf-8')
for code, values in translations.items():
    if code in ('tr','en'): continue
    text = add_to_map(text, f"  '{code}': <String, String>{{\n", values)
gen.write_text(text, encoding='utf-8')
print(f'updated={len(translations)} languages')
