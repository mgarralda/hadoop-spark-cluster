$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    Write-Host 'Ubuntu 24.04 + Hadoop 3.5.0 + Spark 4.2.0 + OpenJDK 17'
    $images = @(
        @{ File = 'Dockerfile'; Name = 'hadoop_spark_base_image' },
        @{ File = 'master/Dockerfile'; Name = 'spark_master' },
        @{ File = 'slave/Dockerfile'; Name = 'spark_slave' },
        @{ File = 'Dockerfile.jupyter'; Name = 'spark_jupyter' }
    )
    foreach ($image in $images) {
        Write-Host "Building $($image.Name)"
        docker build -f $image.File -t "$($image.Name):4.2.0" .
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed for $($image.Name)"
        }
    }
} finally {
    Pop-Location
}
