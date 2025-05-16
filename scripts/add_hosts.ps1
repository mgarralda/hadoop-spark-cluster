Write-Host "Adding hosts"

$hostsPath = "$env:SystemRoot\System32\drivers\etc\hosts"
$entry = "127.0.0.1`t spark-cluster-master"
Add-Content -Path $hostsPath -Value $entry
1..3 | ForEach-Object {
  $entry = "127.0.0.1`t spark-cluster-slave-$_"
  Add-Content -Path $hostsPath -Value $entry
}

Write-Host "Suscessfully added"