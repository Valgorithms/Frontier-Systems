param(
    [string]$Godot = 'D:\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe',
    [ValidateRange(1, 120)][int]$TimeoutSeconds = 60
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$executable = (Get-Command $Godot -CommandType Application | Select-Object -First 1).Source
$output = Join-Path $projectRoot 'var/captures/machinery-activity'
$overridePath = Join-Path $projectRoot 'override.cfg'
if (Test-Path -LiteralPath $overridePath) { throw 'Preserve existing override.cfg; use an isolated checkout.' }
New-Item -ItemType Directory -Force -Path $output | Out-Null
$taskProfile = 'FrontierSystems-activity-' + [Guid]::NewGuid().ToString('N')
$manifest = [ordered]@{
    head_sha = (& git -C $projectRoot rev-parse HEAD).Trim()
    dirty = @(& git -C $projectRoot status --porcelain)
    godot = $executable
    renderer = 'gl_compatibility'
    fixture = 'tools/godot/capture_machinery_activity.gd'
    sockets = $false
    profile = $taskProfile
    started_utc = [DateTime]::UtcNow.ToString('o')
    acceptance = 'Native actual shell, paid domain observations and procedural transforms. No human/controller/VR/Linux graphical/network acceptance.'
    sources = @()
    captures = @()
}
$process = $null
try {
    [IO.File]::WriteAllText($overridePath, "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$taskProfile`"`n")
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
    foreach ($argument in @('--xr-mode', 'off', '--audio-driver', 'Dummy', '--rendering-method', 'gl_compatibility', '--path', '.', '--script', 'res://tools/godot/capture_machinery_activity.gd')) {
        $info.ArgumentList.Add($argument)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo = $info
    if (-not $process.Start()) { throw 'Native activity renderer did not start.' }
    $stdout = $process.StandardOutput.ReadToEndAsync()
    $stderr = $process.StandardError.ReadToEndAsync()
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill($true)
        $process.WaitForExit()
        throw 'Native activity capture exceeded its deadline.'
    }
    $log = $stdout.GetAwaiter().GetResult() + $stderr.GetAwaiter().GetResult()
    [IO.File]::WriteAllText((Join-Path $output 'native.log'), $log)
    if ($process.ExitCode -ne 0 -or $log -match '(?m)SCRIPT ERROR|(?:^|\s)ERROR:') {
        Write-Host $log.Substring(0, [Math]::Min(3000, $log.Length))
        throw 'Native activity verification failed.'
    }
    foreach ($name in @('running-a', 'running-b', 'paused', 'unknown', 'refinery-running', 'disconnected')) {
        $file = Join-Path $output "$name.png"
        if (-not (Test-Path -LiteralPath $file)) { throw "Missing native capture $name" }
        $manifest.captures += @{name=$name;sha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash}
    }
    foreach ($path in @('src/presentation/production/machinery_preview.gd', 'src/presentation/production/machinery_activity_animation.gd', 'src/presentation/production/machinery_activity_parts.gd', 'tools/godot/capture_machinery_activity.gd')) {
        $manifest.sources += @{path=$path;sha256=(Get-FileHash -LiteralPath (Join-Path $projectRoot $path) -Algorithm SHA256).Hash}
    }
    Write-Host 'PASS native machinery activity stills; paid actual-shell fixture, no sockets.'
} finally {
    if ($null -ne $process) {
        if (-not $process.HasExited) { $process.Kill($true) }
        $process.Dispose()
    }
    Remove-Item -LiteralPath $overridePath -ErrorAction SilentlyContinue
    [IO.File]::WriteAllText((Join-Path $output 'manifest.json'), ($manifest | ConvertTo-Json -Depth 6))
}
