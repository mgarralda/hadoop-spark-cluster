$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    function Invoke-DockerCheck {
        param([string[]]$DockerArgs)
        $output = & docker @DockerArgs
        if ($LASTEXITCODE -ne 0) { throw "Docker check failed: $($DockerArgs -join ' ')" }
        return $output
    }
    function Get-StorageIdentities {
        $identities = @{}
        foreach ($node in @('master', 'slave-1', 'slave-2', 'slave-3')) {
            $kind = if ($node -eq 'master') { 'namenode' } else { 'datanode' }
            $lines = Invoke-DockerCheck -DockerArgs @('exec', "spark-cluster-$node", 'cat',
                "/home/sparker/hadoop_data/hdfs/$kind/current/VERSION")
            $identities[$node] = (($lines | Where-Object { $_ -and -not $_.StartsWith('#') } |
                Sort-Object) -join "`n")
        }
        return $identities
    }
    $project = Invoke-DockerCheck -DockerArgs @('inspect', 'spark-cluster-master', '--format',
        '{{index .Config.Labels "com.docker.compose.project"}}')
    if ($project -ne 'spark42-cluster') { throw "Expected spark42-cluster, found $project" }
    $before = Get-StorageIdentities
    $historyBefore = (Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master',
        'curl', '-fsS', 'http://localhost:18080/api/v1/applications')) -join "`n" | ConvertFrom-Json
    $completed = @($historyBefore | Where-Object { $_.attempts.completed -contains $true } |
        Select-Object -ExpandProperty id)
    $marker = "spark42-persistence-$([guid]::NewGuid().ToString('N'))"
    $hdfsPath = "/tmp/$marker"
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'hdfs', 'dfs',
        '-touchz', $hdfsPath) | Out-Host
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'bash', '-c',
        'printf "%s" "$1" | hdfs dfs -appendToFile - "$2"', '--', $marker, $hdfsPath) | Out-Host
    # Never use -v: this test must preserve all named volumes.
    Invoke-DockerCheck -DockerArgs @('compose', 'down') | Out-Host
    Invoke-DockerCheck -DockerArgs @('compose', 'up', '-d', '--wait', '--wait-timeout', '300') | Out-Host
    $after = Get-StorageIdentities
    foreach ($node in $before.Keys) {
        if ($before[$node] -cne $after[$node]) { throw "Storage identity changed: $node" }
    }
    $content = (Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master',
        'hdfs', 'dfs', '-cat', $hdfsPath)) -join "`n"
    if ($content -cne $marker) { throw "Persistence marker mismatch: $hdfsPath" }
    $deadline = (Get-Date).AddSeconds(120)
    do {
        $historyAfter = (Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master',
            'curl', '-fsS', 'http://localhost:18080/api/v1/applications')) -join "`n" | ConvertFrom-Json
        $restored = @($historyAfter | Where-Object { $_.attempts.completed -contains $true } |
            Select-Object -ExpandProperty id)
        $missing = @($completed | Where-Object { $_ -notin $restored })
        if ($missing.Count -eq 0) { break }
        if ((Get-Date) -ge $deadline) { throw "History entries missing after recreation: $missing" }
        Start-Sleep -Seconds 3
    } while ($true)
    Invoke-DockerCheck -DockerArgs @('exec', 'spark-cluster-master', 'hdfs', 'dfs',
        '-rm', $hdfsPath) | Out-Host
    Write-Host "PASS: HDFS content, four storage identities and $($completed.Count) completed history entries survived recreation."
} finally {
    Pop-Location
}
