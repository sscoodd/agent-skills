# Observium: syslog-слежение за изменениями конфигурации

Syslog даёт мгновенный сигнал «конфигурацию изменили: кто, откуда,
когда». Что именно изменилось — покажет дифф из Oxidized (см.
`../oxidized/`). Настраивается один раз, дальше работает на всю
группу.

## 1. Включить приём syslog в Observium

В `config.php` (см. `config.php.snippet.php`):

```php
$config['enable_syslog'] = 1;
```

Затем скормить syslog-поток скрипту Observium через rsyslog на том же
сервере. Классический рецепт (сверьте с docs.observium.org/syslog —
формат шаблона должен соответствовать вашей версии Observium):

```
# /etc/rsyslog.d/30-observium.conf
module(load="omprog")

template(name="observium" type="string"
  string="%fromhost%||%syslogfacility%||%syslogpriority%||%syslogseverity%||%syslogtag%||%$year%-%$month%-%$day% %timegenerated:8:25%||%msg%\n")

# принимать только с management-сети свичей
if $fromhost-ip startswith '<MGMT_PREFIX>' then {
  action(type="omprog"
         binary="/opt/observium/syslog.php"
         template="observium")
}
```

Плюс включить приём UDP/514 в rsyslog (`module(load="imudp")` +
`input(type="imudp" port="514")`), открыть порт с management-сети.

Проверка: сделать любое изменение на свиче → сообщение видно в
Observium на вкладке Syslog устройства. Пока это не работает — дальше
не идти.

## 2. Правила на сообщения об изменении конфигурации

**Syslog → Syslog Rules → Add rule.** Правило = регэксп по тексту
сообщения + ассоциация с устройствами + генерация алерта.

| Вендор | Регэксп |
|---|---|
| Cisco IOS/IOS-XE | `%SYS-5-CONFIG_I\|%PARSER-5-CFGLOG_LOGGEDCMD` |
| Cisco NX-OS | `%VSHD-5-VSHD_SYSLOG_CONFIG_I` |
| Другой вендор | снять образец: изменить description тестового порта, скопировать пришедшую строку из вкладки Syslog, написать регэксп по ней |

- Ассоциация: device group `core-switches`.
- Включить генерацию алерт-записей у правила и привязать контакт
  дежурных — уведомление уходит в момент изменения, с исходной
  строкой syslog (в ней имя пользователя и источник).

Рекомендация: правило «изменение конфига» делать **warn**, не crit —
оно срабатывает и на легитимные работы. Его ценность — корреляция:
инцидент в 14:03 + «config changed by ivanov» в 14:01 экономит час
диагностики.

## 3. Cisco: пер-командный лог (сильно рекомендуется)

На IOS/IOS-XE включить архивный лог конфигурации — тогда в syslog
уходит **каждая введённая команда** (`%PARSER-5-CFGLOG_LOGGEDCMD:
User:ivanov logged command:interface Gi1/0/1 ...`), а не только факт
входа в conf t:

```
archive
 log config
  logging enable
  notify syslog contenttype plaintext
  hidekeys
```

`hidekeys` обязателен — пароли из команд не попадут в syslog.

## 4. Опционально: мгновенный бэкап по событию

По умолчанию Oxidized снимает конфиг раз в час. Чтобы дифф приезжал
через минуту после изменения, а не в конце часа, можно по
syslog-событию дёргать API Oxidized:

```
curl -s "http://127.0.0.1:8888/node/next/<hostname>"
```

— ставит устройство первым в очередь опроса. Проще всего повесить на
rsyslog `omprog`-действие с фильтром по тем же регэкспам. Шаг
необязательный: часовой интервал для начала достаточен.
