$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
Push-Location $projectRoot
try {
    Write-Host 'Ubuntu 22.04 + Hadoop 3.3.6 + Spark 3.5.9 + OpenJDK 11'
    $images = @(
        @{ File = 'Dockerfile'; Name = 'hadoop_spark_base_image' },
        @{ File = 'master/Dockerfile'; Name = 'spark_master' },
        @{ File = 'slave/Dockerfile'; Name = 'spark_slave' },
        @{ File = 'Dockerfile.jupyter'; Name = 'spark_jupyter' }
    )
    foreach ($image in $images) {
        Write-Host "Building $($image.Name)"
        docker build -f $image.File -t $image.Name .
        if ($LASTEXITCODE -ne 0) {
            throw "Build failed for $($image.Name)"
        }
    }
} finally {
    Pop-Location
}
