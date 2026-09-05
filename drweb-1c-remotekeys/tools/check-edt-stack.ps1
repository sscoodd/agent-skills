# Проверка стека для сборки внешней обработки DrWebRemoteKeys (.epf) — Windows.
# Запуск: powershell -ExecutionPolicy Bypass -File drweb-1c-remotekeys\tools\check-edt-stack.ps1
# Ничего не устанавливает и не меняет — только ищет компоненты и печатает сводку.

$found1C = $false

function Section([string]$t) { Write-Host "`n== $t ==" }
function Ok([string]$t)   { Write-Host "  [OK]      $t" }
function Miss([string]$t) { Write-Host "  [НЕТ]     $t" }

function Find-First([string[]]$patterns) {
    foreach ($p in $patterns) {
        $hit = Get-Item -Path $p -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }
    return $null
}

Section "Java (нужна для EDT)"
$java = Get-Command java -ErrorAction SilentlyContinue
if ($java) {
    $ver = (& java -version 2>&1 | Where-Object { $_ -notmatch '^Picked up' } | Select-Object -First 1)
    Ok "java: $ver"
} else {
    Miss "java не найдена (EDT требует JDK; сам .epf собирается платформой без Java)"
}

Section "1C:EDT (проект, экспорт в XML)"
$edtCli = (Get-Command 1cedtcli -ErrorAction SilentlyContinue).Source
if (-not $edtCli) {
    $edtCli = Find-First @(
        "C:\Program Files\1C\1CE\components\1c-edt-*\1cedtcli*",
        "C:\Program Files (x86)\1C\1CE\components\1c-edt-*\1cedtcli*",
        "$env:LOCALAPPDATA\Programs\1C\1CE\components\1c-edt-*\1cedtcli*"
    )
}
if ($edtCli) { Ok "1cedtcli: $edtCli"; $script:found1C = $true }
else { Miss "1cedtcli (CLI EDT) — не найден ни в PATH, ни в Program Files\1C\1CE" }

$ring = (Get-Command ring -ErrorAction SilentlyContinue).Source
if (-not $ring) {
    $ring = Find-First @(
        "C:\Program Files\1C\1CE\components\*\ring.cmd",
        "C:\Program Files (x86)\1C\1CE\components\*\ring.cmd"
    )
}
if ($ring) { Ok "ring: $ring"; $script:found1C = $true }
else { Miss "ring (лаунчер 1C:EDT/лицензий) — не найден" }

Section "Платформа 1С:Предприятие (сборка .epf, ИБ)"
foreach ($b in @("1cv8.exe", "1cv8c.exe", "ibcmd.exe")) {
    $bin = (Get-Command $b -ErrorAction SilentlyContinue).Source
    if (-not $bin) {
        $bin = Find-First @(
            "C:\Program Files\1cv8\*\bin\$b",
            "C:\Program Files (x86)\1cv8\*\bin\$b"
        )
    }
    if ($bin) { Ok "${b}: $bin"; $script:found1C = $true }
    else { Miss "$b — не найден" }
}

Section "Сводка"
@"
  Минимальные комплекты (достаточно одного):
    A. Платформа (1cv8.exe): создать пустую файловую ИБ и собрать .epf одной командой:
       1cv8.exe DESIGNER /F <путь_ИБ> /LoadExternalDataProcessorOrReportFromFiles <xml> <epf>
       (XML-выгрузку обработки готовит EDT или Конфигуратор)
    B. EDT (1cedtcli): вести проект обработки и экспортировать в XML; для финальной
       сборки .epf всё равно нужна платформа (комплект A).
  Полный конвейер: EDT (проект/XML) + платформа (сборка .epf) + Java (для EDT).
"@ | Write-Host

if (-not $found1C) {
    Write-Host "ИТОГ: компоненты стека 1С/EDT не найдены (Java не в счёт)."
    exit 1
}
Write-Host "ИТОГ: компоненты 1С/EDT найдены — детали выше."
exit 0
