<#
.SYNOPSIS
    Entpackt das ExifTool-Archiv in den Zielordner.

.DESCRIPTION
    Wird vom Installationsprogramm aufgerufen, laeuft aber auch einzeln.

    Die ausfuehrbare Datei im Archiv heisst exiftool(-k).exe. Das -k laesst das
    Programm nach jedem Aufruf auf einen Tastendruck warten; das Importskript
    bliebe daran haengen. Sie wird deshalb in exiftool.exe umbenannt. Der Ordner
    exiftool_files daneben muss mit, ohne ihn startet die Datei nicht.

    Der Aufbau des Archivs wird gesucht, nicht vorausgesetzt: Eine neue Fassung
    darf die Dateien auch ohne Oberordner oder bereits ohne -k mitbringen.

.PARAMETER Archiv
    Pfad zur heruntergeladenen ZIP-Datei.

.PARAMETER Ziel
    Ordner, in dem exiftool.exe danach liegt. Wird neu angelegt.

.EXAMPLE
    .\Entpacke-ExifTool.ps1 -Archiv C:\Temp\exiftool-13.59_64.zip -Ziel C:\Programme\exiftool
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Archiv,
    [Parameter(Mandatory = $true)][string]$Ziel
)

$ErrorActionPreference = 'Stop'

try {
    if (-not (Test-Path -LiteralPath $Archiv -PathType Leaf)) {
        throw "Archiv nicht gefunden: $Archiv"
    }

    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("gdmi-exiftool-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $temp -Force | Out-Null

    try {
        Expand-Archive -LiteralPath $Archiv -DestinationPath $temp -Force

        $exe = Get-ChildItem -LiteralPath $temp -Recurse -File |
               Where-Object { $_.Name -eq 'exiftool(-k).exe' -or $_.Name -eq 'exiftool.exe' } |
               Select-Object -First 1
        if (-not $exe) {
            throw "Im Archiv steckt keine exiftool.exe. Stimmt die heruntergeladene Datei?"
        }

        $quellOrdner = $exe.DirectoryName
        $beidateien  = Join-Path $quellOrdner 'exiftool_files'
        if (-not (Test-Path -LiteralPath $beidateien -PathType Container)) {
            throw "Neben $($exe.Name) fehlt der Ordner exiftool_files; ohne ihn startet ExifTool nicht."
        }

        if (Test-Path -LiteralPath $Ziel -PathType Container) {
            Remove-Item -LiteralPath $Ziel -Recurse -Force
        }
        New-Item -ItemType Directory -Path $Ziel -Force | Out-Null

        Copy-Item -LiteralPath $exe.FullName -Destination (Join-Path $Ziel 'exiftool.exe') -Force
        Copy-Item -LiteralPath $beidateien -Destination $Ziel -Recurse -Force

        # Alles andere aus demselben Ordner mitnehmen, darunter die Lizenz- und
        # README-Dateien von ExifTool.
        Get-ChildItem -LiteralPath $quellOrdner -File |
            Where-Object { $_.FullName -ne $exe.FullName } |
            ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $Ziel -Force }

        $zielExe = Join-Path $Ziel 'exiftool.exe'
        if (-not (Test-Path -LiteralPath $zielExe -PathType Leaf)) {
            throw "Nach dem Entpacken fehlt $zielExe."
        }
        Write-Host "ExifTool entpackt nach: $Ziel"
    } finally {
        Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
    }
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
