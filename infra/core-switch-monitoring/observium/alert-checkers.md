# Observium: чекеры здоровья для свичей ядра

Всё заводится в UI: **Alerts → Alert Checkers → Add Alert Checker**.
Названия метрик и условий ниже — стандартные для Observium; точный
список значений виден в выпадающих списках при создании чекера.

## Подготовка

1. **Группа устройств.** Devices → Groups → создать `core-switches`
   (статически или динамически по регэкспу hostname, например
   `/^core-sw/`). Все чекеры ассоциируются с этой группой — новый
   свич ядра попадает под мониторинг простым добавлением в группу.
2. **Контакты.** Alerts → Contacts → завести получателей:
   - почта дежурной смены (транспорт email — работает из коробки,
     нужен рабочий MTA/SMTP на сервере);
   - Telegram/Slack — проверьте список транспортов в вашей версии
     (Contacts → Add Contact); если транспорта нет — шлюз
     почта→Telegram или webhook-обвязка.
   Контакт привязывается к каждому чекеру на вкладке его настроек.
3. **Конвенция портов.** Ассоциации портовых чекеров фильтруют по
   `ifAlias` (description). Договоритесь и проставьте:
   `CORE: <что>`, `UPLINK: <куда>`, `ISL: <до какого свича>`.

## Чекеры

Severity: **crit** — будят ночью, **warn** — разбор в рабочее время.
Delay — защита от флаппинга: алерт уходит, только если условие
держится дольше указанного. Recovery-уведомления включить у всех.

| # | Название | Entity type | Условие | Delay | Sev |
|---|---|---|---|---|---|
| 1 | Core device down | Device | `device_status equals 0` | 120s | crit |
| 2 | Core device rebooted | Device | `device_uptime < 1800` | 0 | warn |
| 3 | CPU high | Processor | `processor_usage > 85` | 600s | warn |
| 4 | Memory high | Mempool | `mempool_perc > 90` | 600s | warn |
| 5 | Sensor abnormal (t°, напряжение) | Sensor | `sensor_event notequals ok` | 300s | crit |
| 6 | HW status (PSU/FAN/модуль) | Status | `status_event notequals ok` | 60s | crit |
| 7 | Uplink/ISL down | Port | `ifOperStatus notequals up` | 60s | crit |
| 8 | Port errors | Port | `ifInErrors_rate > 1` OR `ifOutErrors_rate > 1` | 300s | warn |
| 9 | Port saturation | Port | `ifInOctets_perc > 85` OR `ifOutOctets_perc > 85` | 900s | warn |
| 10 | BGP peer down (если ядро L3) | BGP Peer | `bgpPeerState notequals established` | 120s | crit |

Условия в одном чекере: несколько строк = AND; для OR (чекеры 8, 9)
переключить режим условий на «any/OR» в настройках чекера.

## Ассоциации (у каждого чекера)

- **Все чекеры:** Device group `equals core-switches`.
- **№ 7 (Uplink/ISL down)** дополнительно, чтобы не алертить на
  каждый access-порт:
  - `ifAdminStatus equals up` (выключенные руками порты молчат);
  - `ifAlias match /^(CORE|UPLINK|ISL)/`.
- **№ 8, 9** — тот же фильтр по `ifAlias`, что и № 7.
- **№ 10** дополнительно: `bgpPeerAdminStatus equals start`
  (административно выключенные пиры не алертят).

## Примечания

- № 2 ловит незамеченные перезагрузки (watchdog, питание): свич
  поднялся сам, «down» мог не успеть сработать — а перезагрузка была.
- № 5 опирается на пороги сенсоров, которые Observium берёт с
  устройства или из своих дефолтов; проверьте на странице устройства
  (вкладка Health), что пороги температур адекватны вашей стойке,
  при необходимости поправьте пороги сенсора там же.
- Пороги № 3, 4, 9 — стартовые. Через 2–3 недели сверить с
  фактической базой по графикам и подтянуть.
- Проверка доставки: у чекера есть тестовая отправка в лог/контакт
  (кнопка Test/Check в списке чекеров) — прогнать для каждого
  контакта до приёмки.
