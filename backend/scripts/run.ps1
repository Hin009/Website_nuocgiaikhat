param([switch]$Package)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $projectRoot
if (Test-Path -LiteralPath '.env') {
    foreach ($line in Get-Content -LiteralPath '.env' -Encoding UTF8) {
        if ($line.Trim().StartsWith('#') -or [string]::IsNullOrWhiteSpace($line)) { continue }
        $pair = $line.Split('=', 2)
        if ($pair.Count -ne 2 -or $pair[0].Trim() -notmatch '^[A-Z][A-Z0-9_]*$') { throw 'Invalid .env line' }
        [Environment]::SetEnvironmentVariable($pair[0].Trim(), $pair[1].Trim(), 'Process')
    }
}
if ($Package) { & '.\mvnw.cmd' clean package } else { & '.\mvnw.cmd' spring-boot:run }
exit $LASTEXITCODE
