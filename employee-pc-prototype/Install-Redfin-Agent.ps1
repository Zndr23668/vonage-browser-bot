$ErrorActionPreference = "Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$src=$PSScriptRoot
$dst=Join-Path $env:LOCALAPPDATA "RemoteProfessional\RedfinAgent"
$version="v24.22.1"
$folder="node-$version-win-x64"
$node=Join-Path $dst "runtime\$folder\node.exe"
$settingsPath=Join-Path $dst "local-settings.json"
function Step($s){Write-Host "";Write-Host "==> $s" -ForegroundColor Cyan}
try {
 if (!(Test-Path (Join-Path $src "agent\server.mjs")) -or !(Test-Path (Join-Path $src "extension\manifest.json"))) { throw "Extract the full Windows installer ZIP first." }
 Step "Copying agent files"
 New-Item -ItemType Directory -Force -Path $dst,(Join-Path $dst "agent"),(Join-Path $dst "extension"),(Join-Path $dst "runtime") | Out-Null
 Copy-Item (Join-Path $src "agent\*") (Join-Path $dst "agent") -Recurse -Force
 Copy-Item (Join-Path $src "extension\*") (Join-Path $dst "extension") -Recurse -Force
 foreach($f in @("Start-Redfin-Agent.ps1","Start-Redfin-Agent.bat","Test-Redfin-Agent.ps1","MAKE-INTEGRATION.md")){if(Test-Path (Join-Path $src $f)){Copy-Item (Join-Path $src $f) $dst -Force}}
 Step "Downloading and verifying Node.js"
 if(!(Test-Path $node)){
  $base="https://nodejs.org/dist/$version";$zip="$folder.zip";$z=Join-Path $env:TEMP $zip;$s=Join-Path $env:TEMP "node-SHASUMS256.txt"
  Invoke-WebRequest "$base/SHASUMS256.txt" -OutFile $s -UseBasicParsing
  Invoke-WebRequest "$base/$zip" -OutFile $z -UseBasicParsing
  $line=Get-Content $s|Where-Object{$_ -match "\s$([regex]::Escape($zip))$"}|Select-Object -First 1
  if(!$line){throw "Official checksum list did not contain the Node.js ZIP."}
  if((Get-FileHash $z -Algorithm SHA256).Hash.ToLowerInvariant() -ne (($line -split "\s+")[0]).ToLowerInvariant()){Remove-Item $z -Force;throw "Node.js checksum mismatch."}
  $tmp=Join-Path $env:TEMP ("rpnode"+[guid]::NewGuid().ToString("N"));New-Item -ItemType Directory $tmp|Out-Null
  try{Expand-Archive $z $tmp -Force;Copy-Item (Join-Path $tmp $folder) (Join-Path $dst "runtime") -Recurse -Force}finally{Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue;Remove-Item $z,$s -Force -ErrorAction SilentlyContinue}
 }
 if(!(Test-Path $node)){throw "Node.js runtime installation failed."}
 Step "Creating local device settings"
 if(!(Test-Path $settingsPath)){
  do{$id=(Read-Host "Assigned employee ID (required once, e.g. employee-001)").Trim()}while($id -notmatch '^[A-Za-z0-9._-]{1,64}$')
  $b=New-Object byte[] 32;[Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($b)
  $settings=[ordered]@{employeeId=$id;token=([BitConverter]::ToString($b)-replace '-','').ToLowerInvariant();makeWebhookUrl=""}
  $settings|ConvertTo-Json|Set-Content $settingsPath -Encoding UTF8
 }else{$settings=Get-Content $settingsPath -Raw|ConvertFrom-Json}
 if([string]::IsNullOrWhiteSpace([string]$settings.makeWebhookUrl)){
  Write-Host "Optional: connect existing Make scenario Vonage Browser Results. Webhook URL is a secret."
  $url=(Read-Host "HTTPS Make webhook URL (Enter for local-only)").Trim()
  if($url){$u=[Uri]$url;if($u.Scheme -ne "https" -or $u.Host -notmatch '^hook\.[a-z0-9-]+\.make\.com$' -or $u.Query -or $u.Fragment -or $u.AbsolutePath -notmatch '^/[A-Za-z0-9_-]{20,}$'){throw "Invalid Make webhook URL."};$settings.makeWebhookUrl=$u.AbsoluteUri.TrimEnd("/");$settings|ConvertTo-Json|Set-Content $settingsPath -Encoding UTF8}
 }
 $employeeJson=ConvertTo-Json ([string]$settings.employeeId) -Compress
 $tokenJson=ConvertTo-Json ([string]$settings.token) -Compress
 $config='globalThis.RP_AGENT_CONFIG = { baseUrl: "http://127.0.0.1:8765", employeeId: '+$employeeJson+', token: '+$tokenJson+', pollMs: 3000 };'
 Set-Content (Join-Path $dst "extension\config.local.js") $config -Encoding UTF8
 Step "Creating desktop and startup shortcuts"
 $shell=New-Object -ComObject WScript.Shell;$target=Join-Path $dst "Start-Redfin-Agent.bat"
 $desk=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Desktop")) "Remote Professional Agent.lnk"));$desk.TargetPath=$target;$desk.WorkingDirectory=$dst;$desk.Save()
 $startup=$shell.CreateShortcut((Join-Path ([Environment]::GetFolderPath("Startup")) "Remote Professional Agent.lnk"));$startup.TargetPath=$target;$startup.WorkingDirectory=$dst;$startup.Save()
 & $node --check (Join-Path $dst "agent\server.mjs");if($LASTEXITCODE -ne 0){throw "Agent syntax check failed."}
 Write-Host "";Write-Host "Install ready. In Chrome, enable Developer mode at chrome://extensions, click Load unpacked, and select:" -ForegroundColor Green;Write-Host (Join-Path $dst "extension")
 Start-Process "chrome" "chrome://extensions" -ErrorAction SilentlyContinue
 if((Read-Host "Start agent now? (Y/n)") -notmatch '^(n|no)$'){Start-Process $target -WorkingDirectory $dst;Start-Sleep 3;& (Join-Path $dst "Test-Redfin-Agent.ps1") -WaitSeconds 20}
} catch {Write-Host "";Write-Host "INSTALL FAILED: $($_.Exception.Message)" -ForegroundColor Red;exit 1}