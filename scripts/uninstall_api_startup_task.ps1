$ErrorActionPreference = "Stop"

$taskName = "INTEMA ERP API"

if (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue) {
  Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
  Unregister-ScheduledTask -TaskName $taskName -Confirm:$false
  Write-Host "Tarea eliminada: $taskName"
} else {
  Write-Host "No existe la tarea: $taskName"
}
