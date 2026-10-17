param(
    [string]$Godot = 'godot',
    [string]$OutputDirectory = '',
    [ValidateRange(30, 300)][int]$TimeoutSeconds = 180
)
# Native non-generative movie capture, no sockets, uploads or persistent game data.
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$executable = (Get-Command $Godot -CommandType Application).Source
if (-not $OutputDirectory) { $OutputDirectory = Join-Path $projectRoot 'var/captures/telegram-teaser' }
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$OutputDirectory = (Resolve-Path -LiteralPath $OutputDirectory).Path
$overridePath = Join-Path $projectRoot 'override.cfg'
if (Test-Path -LiteralPath $overridePath) { throw 'Preserve existing override.cfg; use a clean isolated worktree.' }
$profileName = 'FrontierSystems-teaser-' + [Guid]::NewGuid().ToString('N')
$process = $null
try {
    [IO.File]::WriteAllText($overridePath, "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$profileName`"`n`n[display]`nwindow/size/viewport_width=1280`nwindow/size/viewport_height=720`n")
    $info = [Diagnostics.ProcessStartInfo]::new()
    $info.FileName = $executable
    $info.WorkingDirectory = $projectRoot
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.Environment['FRONTIER_EVENT_URL'] = ''
    $info.Environment['FRONTIER_EVENT_TOKEN'] = ''
    $info.Environment['FRONTIER_TEASER_OUTPUT'] = $OutputDirectory
    foreach ($argument in @('--xr-mode','off','--audio-driver','Dummy','--rendering-method','gl_compatibility','--resolution','1280x720','--path',$projectRoot,'--script','res://tools/godot/capture_telegram_teaser.gd','--fixed-fps','30','--write-movie',(Join-Path $OutputDirectory 'raw.avi'))) {
        $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Native movie capture did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw 'Owned movie capture exceeded its deadline.'
    }
    $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $OutputDirectory 'capture.log'), $log)
    if ($process.ExitCode -ne 0 -or $log -match '(?m)SCRIPT ERROR|(?:^|\s)ERROR:') {
        Write-Host $log.Substring(0, [Math]::Min(3000, $log.Length))
        throw 'Native capture failed; inspect capture.log.'
    }
    Write-Host "Native capture completed: $OutputDirectory"
    $log | Select-String -Pattern 'Machinery integration|TEASER_'
} finally {
    if ($null -ne $process) {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
    Remove-Item -LiteralPath $overridePath -ErrorAction SilentlyContinue
}
