# Executa DDL + seeds em ordem no banco safetech.
# Uso: .\run_all.ps1 [-NoSeed]
param(
    [switch]$NoSeed
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not $env:PGHOST)     { $env:PGHOST     = "localhost" }
if (-not $env:PGPORT)     { $env:PGPORT     = "5432" }
if (-not $env:PGUSER)     { $env:PGUSER     = "postgres" }
if (-not $env:PGDATABASE) { $env:PGDATABASE = "safetech" }

function Invoke-SqlFile([string]$Path) {
    Write-Host ">> $Path"
    psql -v ON_ERROR_STOP=1 -q -f $Path
    if ($LASTEXITCODE -ne 0) { throw "Falha ao executar $Path" }
}

Get-ChildItem -Path "ddl" -Filter "*.sql" | Sort-Object Name | ForEach-Object { Invoke-SqlFile $_.FullName }

if (-not $NoSeed) {
    Get-ChildItem -Path "seeds" -Filter "*.sql" | Sort-Object Name | ForEach-Object { Invoke-SqlFile $_.FullName }
}

Write-Host "Concluído."
