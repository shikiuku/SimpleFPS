$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut("C:\Users\k4849\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Godot_v4.4.lnk")
Write-Host $Shortcut.TargetPath