# Хендофф для сессии с EDT-стеком

Инструкция для окружения, где установлен стек 1С (EDT и/или платформа) — Linux или
Windows. Цель — собрать из исходников этой папки готовую внешнюю обработку
`DrWebRemoteKeys.epf` и вернуть в репозиторий XML-выгрузку (а по возможности и сам `.epf`).

Контекст проекта агент получает автоматически из [../CLAUDE.md](../CLAUDE.md). Дизайн
формы — [Интерфейс.md](Интерфейс.md) и `Интерфейс-макет.html`. Список реквизитов —
[СборкаОбработки.md](СборкаОбработки.md).

## Шаг 0. Проверка стека

Linux/macOS/Git Bash:

```bash
bash drweb-1c-remotekeys/tools/check-edt-stack.sh
```

Windows (PowerShell):

```powershell
powershell -ExecutionPolicy Bypass -File drweb-1c-remotekeys\tools\check-edt-stack.ps1
```

Скрипты ищут `java`, `1cedtcli`/`ring` (EDT) и `1cv8`/`1cv8c`/`ibcmd` (платформа) в PATH
и типовых путях (`/opt/1C/1CE/...`, `/opt/1cv8/...`; на Windows —
`C:\Program Files\1C\1CE\components\...`, `C:\Program Files\1cv8\<версия>\bin\...`)
и печатают сводку `[OK]/[НЕТ]`; exit 1 — если компонентов 1С нет.

## Шаг 1. Создать обработку

Два равноценных пути — выбрать по наличию инструментов:

### Путь A: платформа (Конфигуратор headless не умеет создавать с нуля — нужен GUI)
Если есть только платформа с GUI-конфигуратором — собрать по шагам из
[СборкаОбработки.md](СборкаОбработки.md) (создать обработку → вставить
`src/МодульОбъекта.bsl` → форма с реквизитами → команды → `src/МодульФормы.bsl`).

### Путь B: EDT
1. Создать проект внешней обработки `DrWebRemoteKeys` (External data processor).
2. Модуль объекта — целиком из `src/МодульОбъекта.bsl`.
3. Основная управляемая форма — реквизиты и команды по таблицам из
   [СборкаОбработки.md](СборкаОбработки.md), модуль формы — из `src/МодульФормы.bsl`.
4. Компоновка формы — по [Интерфейс.md](Интерфейс.md) (группы/страницы: Учётные данные,
   Генерация, Блокировка, Информация, Результат).

## Шаг 2. Экспорт в XML и сборка .epf

1. Экспортировать обработку в XML (Designer-формат): EDT → «Экспорт конфигурации в
   XML» / `1cedtcli` export, либо Конфигуратор → «Выгрузить внешнюю обработку в файлы».
   Положить в `drweb-1c-remotekeys/build-src/DrWebRemoteKeys/`.
2. Собрать `.epf` (нужна платформа).

Linux:

```bash
# одноразово: пустая файловая ИБ для сборки
1cv8 CREATEINFOBASE File="/tmp/build-ib" /DisableStartupDialogs
# сборка
1cv8 DESIGNER /F /tmp/build-ib /DisableStartupDialogs \
  /LoadExternalDataProcessorOrReportFromFiles \
  drweb-1c-remotekeys/build-src/DrWebRemoteKeys/DrWebRemoteKeys.xml \
  drweb-1c-remotekeys/build/DrWebRemoteKeys.epf
```

Windows (PowerShell; путь к `1cv8.exe` подставить из вывода check-скрипта):

```powershell
$v8 = "C:\Program Files\1cv8\<версия>\bin\1cv8.exe"   # см. вывод check-edt-stack.ps1
$ib = "$env:TEMP\build-ib"
& $v8 CREATEINFOBASE "File=""$ib""" /DisableStartupDialogs
& $v8 DESIGNER /F $ib /DisableStartupDialogs `
  /LoadExternalDataProcessorOrReportFromFiles `
  "drweb-1c-remotekeys\build-src\DrWebRemoteKeys\DrWebRemoteKeys.xml" `
  "drweb-1c-remotekeys\build\DrWebRemoteKeys.epf"
```

## Шаг 3. Проверки перед коммитом

- Синтаксический контроль обоих модулей — без ошибок.
- Точка внимания из кода: `КодироватьСтроку(…, СпособКодированияСтроки.URLВКодировке)`
  в `МодульОбъекта.bsl` — если платформа подчёркивает имя члена перечисления,
  подставить доступный вариант.
- Используемые API: `ЗащищенноеСоединениеOpenSSL`, `HTTPСоединение`, `ПостроительDOM`,
  `ЧтениеJSON`/`ПрочитатьJSON`, `СтрШаблон` — платформа 8.3.10+ (у БП 3.0 — с запасом).
- Форма открывается в 1С:Предприятии (или в тонком клиенте на тестовой БП 3.0),
  поля соответствуют [Интерфейс.md](Интерфейс.md).
- Смоук без учётки не сделать; допустимо проверить «Информация по номеру» на любом
  серийнике (endpoint без авторизации, вернёт XML `<serialattrs>`).

## Шаг 4. Вернуть в репозиторий

- Коммитить: `build-src/` (XML-выгрузка) и, если политика позволяет бинарники, —
  `build/DrWebRemoteKeys.epf`.
- Работа ведётся в ветке `claude/drweb-api-utility-0wy3iw` (PR #2). Если у вашей
  сессии назначена другая ветка — коммитьте в неё и напишите в PR #2, чтобы
  скоординировать слияние; не пересоздавайте исходники `src/` — они первичны.

## Что дальше (после сборки v1-формы)

UI-этап 2 (по согласованию): вкладки «Продление», «Цены», «Заказы», «Постфактум»
поверх уже готовых методов ядра (см. таблицу методов в
[Доп-интерфейсы.md](Доп-интерфейсы.md)).
