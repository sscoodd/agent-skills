---
name: obsidian-memory
description: Protocol for using creator/obsidian-vault (a repo on the user's self-hosted Forgejo, address in $FORGEJO_URL) as Claude's long-term memory. Trigger when the user references past work ("my X project", "we decided Y", "remember that..."), asks Claude to remember/save/update/forget something, mentions a project by name (lotus-eletre, uspeak, homework-*, 1c-*, pcb-*, obsidian, claude-skills), or whenever a substantive insight, decision, or fact surfaces that's worth preserving between sessions. Also covers answering non-trivial project questions that benefit from previously stored context. Describes vault layout, frontmatter conventions, Forgejo REST API mechanics (read/list/search/create/update), naming rules, and write permissions. Do NOT trigger for simple one-off technical questions or casual chat that doesn't involve the user's ongoing projects or personal context.
---

# obsidian-memory

Протокол работы с `creator/obsidian-vault` как долговременной памятью.
Vault — обычный git-репо в Forgejo, хранит markdown-заметки с YAML-frontmatter.
Claude читает и пишет заметки через Forgejo REST API.

## Where things live

Адрес и доступ берутся **только из окружения**, в тексте скилла хост не
хардкодится (прошлый хостинг умер, а ссылки на него ещё долго путали Claude):

| Переменная | Что | Дефолт |
|---|---|---|
| `FORGEJO_URL` | базовый URL инстанса, без завершающего `/` | нет, обязательна |
| `FORGEJO_REPO` | `owner/repo` vault'а | `creator/obsidian-vault` |
| `FORGEJO_BRANCH` | ветка | `main` |
| `FORGEJO_TOKEN` | personal access token с правами на чтение и запись в repo | нет, обязательна |

- **Access:** `bash_tool` + `curl` с `Authorization: token $FORGEJO_TOKEN`
- **Проверка в начале сессии:** если `FORGEJO_URL` или `FORGEJO_TOKEN`
  пустые — не гадать адрес и не пробовать старые хосты. Спросить у
  пользователя один раз, дальше использовать в рамках сессии.
- Постоянно задать переменные можно в настройках окружения Claude Code
  (Environment → Environment variables) или в `~/.claude/settings.json` → `env`.

## Vault layout

```
00-inbox/              user's raw notes, READ-ONLY for Claude
10-projects/           active projects (lotus-eletre/, uspeak/, …), READ-ONLY
20-knowledge/          reference (1c/, embedded/, infrastructure/), READ-ONLY
30-daily/              daily log, meetings, READ-ONLY
claude/                Claude's own space, READ-WRITE
├── memory/
│   ├── facts.md       stable facts (one file, append-only section)
│   ├── preferences.md user preferences and standards
│   ├── projects/
│   │   └── <slug>.md  cumulative per-project context
│   └── 1c/            отдельная область: 1С-экосистема пользователя
│       ├── README.md            протокол + конвенции именно для 1С
│       ├── configurations/      КА, ERP, УТ, ЗУП — по конфигурациям
│       └── projects/            клиентские 1С-внедрения
├── insights/          dated observations: YYYY-MM-DD-<slug>.md
├── conversations/     session summaries: YYYY-MM-DD-<slug>.md
└── inbox/             drafts for user review
```

**Areas vs projects:** `claude/memory/projects/` — разовый контекст
одного проекта в одном файле. `claude/memory/<area>/` — целая
тематическая область со своей подструктурой. Сейчас такая есть одна
(`1c/`), могут появиться ещё (`embedded/`, `infrastructure/` если
разрастётся из `facts.md`). Решение «один файл vs целая папка»
принимается по тому, нужна ли внутренняя структура (конфигурации,
клиенты, паттерны) — если да, это область.

### 1С — special case

В начале любого разговора, где всплывают 1С-темы (конфигурации КА/ERP/УТ/ЗУП,
внедрения, BSL-код, интеграции с Bitrix24, ТЗ на 1С-проекты):

1. Прочитать `claude/memory/1c/README.md` — там протокол
2. Листинг `configurations/` и `projects/` — увидеть актуальный набор
3. Прицельно 2–3 релевантных файла
4. Параллельно — skill `1c-analyst` для процедурных знаний
   (как делать); vault — для «что у пользователя конкретно есть и как»

**Write rule:** Claude пишет *только* в `claude/**`. Всё остальное —
read-only. Если кажется что стоит дополнить `20-knowledge/…` — положить
в `claude/inbox/` с пометкой «proposed addition to <path>» и отдать
пользователю на ревью.

## Frontmatter

Каждый файл в `claude/**` начинается с YAML-frontmatter:

```yaml
---
type: memory | insight | conversation | fact | preference
project: <slug>              # опционально; lotus-eletre, uspeak, и т.п.
tags: [<tag1>, <tag2>]       # свободная форма, kebab-case
created: YYYY-MM-DD
updated: YYYY-MM-DD
relevance: 0.0-1.0           # оценка важности, используется при ранжировании
confidence: low | medium | high
private: false               # true → не использовать в ответах, не упоминать наличие
sources:                     # опционально: откуда знание пришло
  - conversation: 2026-04-19-lotus-yaw-calibration
  - url: https://…
---
```

`private: true` — сильное правило. Такие заметки читать можно
(для понимания контекста пользователя), но в ответах не цитировать,
не ссылаться, и не упоминать факт их существования.

## Protocol

### 1. В начале содержательного разговора

Если разговор касается проекта/системы/темы, по которым у пользователя
может быть накопленный контекст:

1. **Поиск по теме.** Content-поиск по vault через API:
   ```
   GET /api/v1/repos/$FORGEJO_REPO/search?q=<keyword>&type=code
   ```
   Альтернатива для поиска по frontmatter-полю — grep по всем файлам в
   `claude/memory/projects/`:
   ```
   GET /api/v1/repos/$FORGEJO_REPO/contents/claude/memory/projects
   ```
2. **Читаем top-3..5 самых релевантных.** Приоритет: свежесть (`updated`),
   явный `project` match, высокий `relevance`. Исключить `private: true`
   из ответов (но прочитать можно).
3. **Использовать контекст** в ответе естественно, без меты про «я
   нашёл заметку...».

### 2. Когда НЕ искать

- Простые технические вопросы без персонального контекста
  («как в Python отсортировать список по ключу»)
- Разговорная болтовня, приветствия
- Одноразовые операции
- Вопросы, где пользователь сам дал весь нужный контекст в сообщении

### 3. В процессе разговора

- При упоминании сущностей, имеющих свою заметку в vault, использовать
  `[[wiki-links]]` в новых заметках (пригодится для навигации в Obsidian)
- Если обнаружилось противоречие между памятью и тем что говорит
  пользователь сейчас — честно сказать («в заметках было X, сейчас Y —
  обновить?»), не тихо исправлять

### 4. В конце содержательного разговора

Если всплыли значимые инсайты / факты / решения — сохранить:

| Что появилось | Куда класть |
|---|---|
| Одноразовое наблюдение по проекту | `claude/insights/YYYY-MM-DD-<slug>.md` |
| Накопительный контекст по проекту (обновляется) | `claude/memory/projects/<slug>.md` |
| Стабильный факт общего характера | `claude/memory/facts.md` (append в секцию) |
| Предпочтение пользователя | `claude/memory/preferences.md` |
| Выжимка самой беседы | `claude/conversations/YYYY-MM-DD-<slug>.md` |
| Сомневаешься куда — | `claude/inbox/` + explicit note пользователю |

**Не писать ради галочки.** Лучше 0 файлов, чем пять пустословных.
Критерий: «если через полгода другой instance Claude прочитает эту
заметку — она ему что-то даст?».

## Forgejo REST API — шпаргалка

```bash
: "${FORGEJO_URL:?FORGEJO_URL is not set — ask the user for the Forgejo address}"
: "${FORGEJO_TOKEN:?FORGEJO_TOKEN is not set — ask the user for a token}"
REPO=${FORGEJO_REPO:-creator/obsidian-vault}
BRANCH=${FORGEJO_BRANCH:-main}
API="$FORGEJO_URL/api/v1"
AUTH="Authorization: token $FORGEJO_TOKEN"

# Smoke test: доступен ли инстанс и репо
curl -sS -f -H "$AUTH" "$API/repos/$REPO" >/dev/null && echo ok

# ── READ ────────────────────────────────────────────────────────────────────

# Прочитать файл (raw содержимое)
curl -sS -H "$AUTH" "$API/repos/$REPO/raw/claude/memory/facts.md?ref=$BRANCH"

# Листинг папки (metadata всех файлов)
curl -sS -H "$AUTH" "$API/repos/$REPO/contents/claude/memory/projects?ref=$BRANCH" \
  | python3 -c "import sys,json; [print(x['path'], x['size']) for x in json.load(sys.stdin)]"

# Content-поиск (требует включённый code-индекс на уровне инстанса Forgejo)
curl -sS -H "$AUTH" "$API/repos/$REPO/search?q=eletre+alignment&type=code"

# Tree (вся структура целиком с recursive)
curl -sS -H "$AUTH" "$API/repos/$REPO/git/trees/$BRANCH?recursive=true"

# ── WRITE ───────────────────────────────────────────────────────────────────

# Создать новый файл (POST contents). Содержимое — base64.
content_b64=$(base64 -w0 note.md)
curl -sS -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "$API/repos/$REPO/contents/claude/insights/2026-04-19-foo.md" \
  -d "{
    \"message\": \"claude: insight on X\",
    \"content\": \"$content_b64\",
    \"branch\": \"$BRANCH\"
  }"

# Обновить существующий файл (PUT, нужен sha текущей версии)
sha=$(curl -sS -H "$AUTH" "$API/repos/$REPO/contents/claude/memory/facts.md?ref=$BRANCH" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['sha'])")
content_b64=$(base64 -w0 facts-new.md)
curl -sS -X PUT -H "$AUTH" -H "Content-Type: application/json" \
  "$API/repos/$REPO/contents/claude/memory/facts.md" \
  -d "{
    \"message\": \"claude: update facts — add Eletre calibration notes\",
    \"content\": \"$content_b64\",
    \"sha\": \"$sha\",
    \"branch\": \"$BRANCH\"
  }"

# Batch (несколько файлов одним коммитом) — POST contents БЕЗ пути
curl -sS -X POST -H "$AUTH" -H "Content-Type: application/json" \
  "$API/repos/$REPO/contents" \
  -d "{
    \"branch\": \"$BRANCH\",
    \"message\": \"claude: session summary with 2 artefacts\",
    \"files\": [
      {\"operation\":\"create\", \"path\":\"claude/conversations/…\", \"content\":\"<b64>\"},
      {\"operation\":\"update\", \"path\":\"claude/memory/projects/…\", \"content\":\"<b64>\", \"sha\":\"<prev-sha>\"}
    ]
  }"
```

## Gotchas (learned the hard way)

1. **`content`, не `content_base64`.** В `POST /contents` (включая batch)
   поле называется `content`. Если послать `content_base64` — Forgejo тихо
   проигнорирует неизвестный ключ и создаст файл нулевого размера. Файл
   «появится», коммит пройдёт, а содержимое будет пустое.
2. **URL-encode путей.** Папки с пробелами/кириллицей → encode перед
   API-вызовом: `curl "…/contents/30-daily/2026-04-19%20%D0%B4%D0%B5%D0%BD%D1%8C.md"`.
3. **`PUT` требует `sha` текущей версии.** Забыл sha — получишь 409.
   Всегда перечитывать перед update'ом.
4. **Новый репо «пустой» после `auto_init=true`.** Первый commit через
   API создаёт initial commit и ветку main. До этого момента API
   `?ref=main` возвращает 404.
5. **Rate limit.** По умолчанию Forgejo не агрессивен, но batch-операции
   предпочтительнее N одиночных запросов — один коммит лучше для истории
   и дешевле по HTTP.
6. **Хост недоступен (DNS/timeout/HTTP 5xx).** Не подставлять другие
   адреса по памяти и не искать «старый» инстанс — сообщить пользователю
   и попросить актуальный `FORGEJO_URL`.

## Commit message format

Все коммиты Claude в vault — префикс `claude:`:

- `claude: save <тема> from conversation` — новая заметка
- `claude: update <путь> — <что именно>` — правка
- `claude: merge <откуда> → <куда>` — переорганизация
- `claude: remove <путь> — <причина>` (редко; чаще `private: true`)

Это позволяет пользователю легко фильтровать `git log | grep ^claude:`
и понять что делал Claude в vault.

## Naming

- `claude/insights/YYYY-MM-DD-<slug>.md` — slug kebab-case, ASCII
- `claude/conversations/YYYY-MM-DD-<slug>.md` — аналогично
- `claude/memory/projects/<slug>.md` — slug совпадает с
  `10-projects/<slug>/` если проект существует
- `claude/memory/<topic>.md` — accumulating files (facts, preferences)

Русские названия → транслит или короткий англ. эквивалент.
`лотос-настройка-развала` → `lotus-alignment`.

## Boundaries

- **Не писать в пользовательские папки** (00–30). Если нужно предложить
  изменение — в `claude/inbox/` с пометкой.
- **Не удалять пользовательские файлы никогда.** Свои (`claude/**`) —
  можно, если очевидно устарело; предпочтительнее `private: true` чем
  удаление (история сохраняется в git, но из выдачи исчезает).
- **Не обходить `private: true`.** Такие заметки не цитировать
  и не упоминать.
- **Честно флагить противоречия** между тем что в vault и что говорит
  пользователь, не исправляя молча.
