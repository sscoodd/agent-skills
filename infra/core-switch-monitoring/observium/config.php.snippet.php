<?php
// Фрагменты для /opt/observium/config.php — добавить к существующему
// конфигу, НЕ заменять файл целиком. После правок прогнать
// ./discovery.php -h all не требуется; syslog подхватывается сразу.

// ── Приём syslog (см. observium/syslog-config-tracking.md) ──────────────
$config['enable_syslog'] = 1;

// ── Почта для алертов ───────────────────────────────────────────────────
// Транспорты/получатели заводятся в UI (Alerts -> Contacts);
// здесь только отправитель и адрес по умолчанию.
$config['email']['from']    = 'observium@<OBSERVIUM_FQDN>';
$config['email']['default'] = '<NOC_EMAIL>';

// ── Вкладка Config у устройства (опционально) ───────────────────────────
// Observium умеет показывать текущий конфиг устройства из каталога
// файлов вида <hostname> (интеграция, исторически сделанная под RANCID —
// проверьте ключи по docs.observium.org для вашей версии).
// Oxidized хранит конфиги в git; для вкладки достаточно периодически
// выгружать рабочую копию в каталог и указать его здесь:
//
//   # cron на сервере, каждые 30 минут:
//   git --git-dir=/opt/oxidized/data/configs.git \
//       --work-tree=/var/lib/oxidized-export checkout -f
//
// $config['rancid_configs'][] = '/var/lib/oxidized-export/';
// $config['rancid_ignorecomments'] = 0;
//
// Полная история и диффы всё равно живут в git/Gitea — вкладка лишь
// удобный просмотр текущего состояния рядом с графиками.
