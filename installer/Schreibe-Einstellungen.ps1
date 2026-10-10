<#
.SYNOPSIS
    Erzeugt config\einstellungen.json aus der Vorlage.

.DESCRIPTION
    Wird vom Installationsprogramm aufgerufen. Die Ordner und der ExifTool-Pfad
    kommen aus dem Assistenten, alle uebrigen Schluessel aus der Vorlage.

    Eine vorhandene Datei bleibt unangetastet: Ein Update darf die Einstellungen
    des Nutzers nicht ueberschreiben. Rueckgabe 2 sagt dem Installer, dass nichts
    geschrieben wurde, damit die Schlussseite es erwaehnen kann.

.PARAMETER Vorlage
    Pfad zu einstellungen.vorlage.json.

.PARAMETER Ziel
    Pfad zur zu schreibenden einstellungen.json.

.EXAMPLE
    .\Schreibe-Einstellungen.ps1 -Vorlage .\config\einstellungen.vorlage.json `
        -Ziel .\config\einstellungen.json -Inbox C:\In -Mediathek C:\MT `
        -Protokolle C:\Log -ExifToolPath C:\Prog\exiftool\exiftool.exe
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Vorlage,
    [Parameter(Mandatory = $true)][string]$Ziel,
    [Parameter(Mandatory = $true)][string]$Inbox,
    [Parameter(Mandatory = $true)][string]$Mediathek,
    [Parameter(Mandatory = $true)][string]$Protokolle,
    [Parameter(Mandatory = $true)][string]$ExifToolPath
)

$ErrorActionPreference = 'Stop'

try {
    if (Test-Path -LiteralPath $Ziel -PathType Leaf) {
        Write-Host "Einstellungen vorhanden, sie bleiben unveraendert: $Ziel"
        exit 2
    }
    if (-not (Test-Path -LiteralPath $Vorlage -PathType Leaf)) {
        throw "Vorlage nicht gefunden: $Vorlage"
    }

    $konfig = [System.IO.File]::ReadAllText($Vorlage) | ConvertFrom-Json
    $konfig.Inbox        = $Inbox
    $konfig.Mediathek    = $Mediathek
    $konfig.Protokolle   = $Protokolle
    $konfig.ExifToolPath = $ExifToolPath

    # ConvertTo-Json maskiert unter Windows PowerShell 5.1 Umlaute als \uXXXX.
    # Gueltiges JSON, aber die Datei soll von Hand lesbar bleiben - dieselbe
    # Behandlung wie beim Speichern ueber die Weboberflaeche.
    $json = $konfig | ConvertTo-Json -Depth 5
    $json = [regex]::Replace($json, '\\u([0-9a-fA-F]{4})', {
        param($m) [char][int]("0x" + $m.Groups[1].Value)
    })

    $ordner = Split-Path -Parent $Ziel
    if ($ordner -and -not (Test-Path -LiteralPath $ordner -PathType Container)) {
        New-Item -ItemType Directory -Path $ordner -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Ziel, $json, (New-Object System.Text.UTF8Encoding $false))
    Write-Host "Einstellungen geschrieben: $Ziel"
} catch {
    Write-Host "FEHLER: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
