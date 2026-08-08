#!/usr/bin/env sh
# Хук Oxidized (exec): уведомление об изменении конфига или об ошибке
# снятия. Вызывается на post_store (успешный коммит диффа) и node_fail.
# Каналы: Telegram (если заданы TG_TOKEN/TG_CHAT), иначе — лог-файл.
# Переменные OX_* выставляет сам Oxidized.

set -eu

NODE="${OX_NODE_NAME:-unknown}"
EVENT="${OX_EVENT:-unknown}"
LOG="/home/oxidized/.config/oxidized/notify.log"

if [ "$EVENT" = "node_fail" ]; then
    TEXT="[oxidized] СБОЙ снятия конфига: ${NODE} (${OX_NODE_IP:-?}): ${OX_ERR_TYPE:-error}"
else
    # post_store: достаём дифф зафиксированного коммита
    REPO="${OX_REPO_NAME:?no repo path}"
    REF="${OX_REPO_COMMITREF:?no commit ref}"
    DIFF="$(git --git-dir="$REPO" show --no-color --stat -p "$REF" 2>&1 | head -c 3500)"
    TEXT="[oxidized] Изменение конфигурации: ${NODE}
${DIFF}"
fi

printf '%s %s\n' "$(date -Iseconds)" "$TEXT" >> "$LOG"

# Telegram, если настроен (переменные пробрасываются в docker-compose.yml)
if [ -n "${TG_TOKEN:-}" ] && [ -n "${TG_CHAT:-}" ]; then
    curl -sS -m 15 -X POST \
        "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
        -d chat_id="${TG_CHAT}" \
        --data-urlencode text="${TEXT}" >/dev/null \
        || printf '%s telegram send failed\n' "$(date -Iseconds)" >> "$LOG"
fi

# Почта вместо/помимо Telegram: если oxidized запущен не в контейнере
# и на хосте есть MTA — раскомментировать.
# printf '%s\n' "$TEXT" | mail -s "[oxidized] ${NODE}: ${EVENT}" "<NOC_EMAIL>"

exit 0
