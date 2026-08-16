#!/usr/bin/env bash
# Проверка стека для сборки внешней обработки DrWebRemoteKeys (.epf).
# Запуск: bash drweb-1c-remotekeys/tools/check-edt-stack.sh
# Ничего не устанавливает и не меняет — только ищет компоненты и печатает сводку.

set -u

found_any=0

section() { printf '\n== %s ==\n' "$1"; }
ok()      { printf '  [OK]      %s\n' "$1"; found_any=1; }
miss()    { printf '  [НЕТ]     %s\n' "$1"; }

first_match() { # glob... -> первый существующий путь
  for p in "$@"; do
    [ -e "$p" ] && { printf '%s' "$p"; return 0; }
  done
  return 1
}

section "Java (нужна для EDT)"
if command -v java >/dev/null 2>&1; then
  printf '  [OK]      %s\n' "java: $(java -version 2>&1 | grep -v '^Picked up' | head -1)"
else
  miss "java не найдена (EDT требует JDK; сам .epf собирается платформой без Java)"
fi

section "1C:EDT (проект, экспорт в XML)"
EDT_CLI="$(command -v 1cedtcli 2>/dev/null || true)"
[ -z "$EDT_CLI" ] && EDT_CLI="$(first_match \
  /opt/1C/1CE/components/1c-edt-*/1cedtcli.sh \
  /opt/1c-edt*/1cedtcli* \
  /opt/edt*/1cedtcli* \
  "$HOME"/.local/share/1C/1cedt/*/1cedtcli* 2>/dev/null || true)"
if [ -n "$EDT_CLI" ]; then
  ok "1cedtcli: $EDT_CLI"
else
  miss "1cedtcli (CLI EDT) — не найден ни в PATH, ни в /opt/1C/1CE, /opt/1c-edt*"
fi

RING="$(command -v ring 2>/dev/null || true)"
[ -z "$RING" ] && RING="$(first_match /opt/1C/1CE/components/*/ring 2>/dev/null || true)"
if [ -n "$RING" ]; then
  ok "ring: $RING"
else
  miss "ring (лаунчер 1C:EDT/лицензий) — не найден"
fi

section "Платформа 1С:Предприятие (сборка .epf, ИБ)"
for b in 1cv8 1cv8c ibcmd; do
  BIN="$(command -v "$b" 2>/dev/null || true)"
  [ -z "$BIN" ] && BIN="$(first_match /opt/1cv8/x86_64/*/"$b" /opt/1cv8/*/"$b" /opt/1C/v8*/x86_64/*/"$b" 2>/dev/null || true)"
  if [ -n "$BIN" ]; then
    ok "$b: $BIN"
  else
    miss "$b — не найден"
  fi
done

section "Сводка"
cat <<'SUMMARY'
  Минимальные комплекты (достаточно одного):
    A. Платформа (1cv8): создать пустую файловую ИБ и собрать .epf одной командой:
       1cv8 DESIGNER /F <путь_ИБ> /LoadExternalDataProcessorOrReportFromFiles <xml> <epf>
       (XML-выгрузку обработки готовит EDT или Конфигуратор)
    B. EDT (1cedtcli): вести проект обработки и экспортировать в XML; для финальной
       сборки .epf всё равно нужна платформа (комплект A).
  Полный конвейер: EDT (проект/XML) + платформа (сборка .epf) + Java (для EDT).
SUMMARY

if [ "$found_any" -eq 0 ]; then
  echo "ИТОГ: компоненты стека 1С/EDT не найдены (Java не в счёт)." >&2
  exit 1
fi
echo "ИТОГ: компоненты 1С/EDT найдены — детали выше."
