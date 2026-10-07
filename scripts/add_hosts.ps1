$ErrorActionPreference = 'Stop'
$hostsPath = Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
$content = Get-Content -LiteralPath $hostsPath
$names = @('spark-cluster-master') + (1..3 | ForEach-Object { "spark-cluster-slave-$_" })
foreach ($name in $names) {
    $escapedName = [regex]::Escape($name)
    $existing = $content | Where-Object {
        ($_ -split '#', 2)[0] -match "(^|\s)$escapedName(\s|$)"
    }
    if (-not $existing) {
        Add-Content -LiteralPath $hostsPath -Value "127.0.0.1`t$name"
        Write-Host "Added $name"
    }
}
Write-Host 'Cluster host entries are configured.'
