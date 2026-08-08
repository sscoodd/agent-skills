# Подготовка самих свичей

Что должно быть включено на каждом свиче ядра, чтобы заработали
алерты, syslog-слежение и бэкап конфигов. Эталонные сниппеты — Cisco
IOS/IOS-XE; для другого вендора те же четыре пункта переносятся
1-в-1, меняется только синтаксис.

## 1. Время (без него диффы и логи бессмысленны)

```
ntp server <NTP_IP>
clock timezone <TZ> <OFFSET>
service timestamps log datetime msec localtime show-timezone
```

## 2. Syslog на сервер Observium

```
logging host <OBSERVIUM_IP>
logging trap informational
logging source-interface <MGMT_IF>
```

Плюс пер-командный лог изменений конфигурации (пароли скрываются):

```
archive
 log config
  logging enable
  notify syslog contenttype plaintext
  hidekeys
```

## 3. Учётка для Oxidized

Отдельная учётка только для снятия конфигов — не общий admin: в
syslog и git видно, что делал робот, а компрометация пароля бэкапа
не отдаёт запись.

```
username oxidized privilege 15 secret <STRONG_PASSWORD>
```

Если используется TACACS+/RADIUS — завести учётку там с правом
`show running-config` и привилегией без права конфигурирования
(предпочтительно). Локальную оставить как fallback.

## 4. Ограничить доступ хостом мониторинга

SSH и SNMP — только с management-сети / адреса сервера мониторинга:

```
ip access-list standard MGMT-ACCESS
 permit host <OBSERVIUM_IP>
 permit <MGMT_PREFIX> <WILDCARD>
 deny any log
line vty 0 15
 access-class MGMT-ACCESS in
 transport input ssh
```

SNMP уже настроен (Observium опрашивает); проверить, что community/
v3-пользователь тоже закрыт ACL-ом, и по возможности перейти на
SNMPv3 authPriv.

## Другие вендоры — соответствие команд

| Пункт | Huawei VRP | Eltex MES |
|---|---|---|
| NTP | `ntp-service unicast-server <IP>` | `sntp server <IP>` + `clock source sntp` |
| Syslog | `info-center loghost <IP>` | `logging host <IP>` |
| Лог команд | `info-center source SHELL channel loghost` (пишет команды операторов) | включить логирование команд в AAA; формат сообщения снять с тестового изменения |
| Учётка | `local-user oxidized privilege level 3` + service-type ssh | `username oxidized privilege 15 password ...` |

Для «лог команд» у не-Cisco вендоров: после настройки сделать
тестовое изменение, посмотреть пришедшую в Observium строку syslog и
по ней написать регэксп правила (см.
`../observium/syslog-config-tracking.md`, раздел 2).
