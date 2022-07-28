# Include config
$configFile = "$PSScriptRoot\MinecraftVersionUpdates.config.ps1"
if (Test-Path $configFile) { . $configFile }
else { "Config file MinecraftVersionUpdates.config.ps1 not found"; exit }

$dbFile = "$PSScriptRoot\MinecraftVersionUpdates.json"

function Main {
	Open-Db
	
	Invoke-CheckVersion 'java' 'release'
	Invoke-CheckVersion 'java' 'snapshot'
	Invoke-CheckVersion 'bedrock' 'release'

	Save-Db
}

function Open-Db {
	$Global:db = Get-Content $dbFile -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable
	if ($null -eq $db) {
		$Global:db = @{}
		$db.variant = @{}
		$db.variant.java = @{}
		$db.variant.java.release = @{}
		$db.variant.java.release.versions = @{}
		$db.variant.java.snapshot = @{}
		$db.variant.java.snapshot.versions = @{}
		$db.variant.bedrock = @{}
		$db.variant.bedrock.release = @{}
		$db.variant.bedrock.release.versions = @{}
	}
}

function Save-Db {
	$db | ConvertTo-Json -Depth 10 | Out-File $dbFile
}

function Invoke-CheckVersion ($variant, $type) {
	if ($variant -eq 'java') { $latest = Get-LatestJava -type $type }
	if ($variant -eq 'bedrock') { $latest = Get-LatestBedrock }
	if (-not $latest) { return $false }
	
	# New version
	if ($latest.version -ne $db.variant.$variant.$type.lastCheck.version) {
		"New version " + $latest.version
		# Store version
		$db.variant.$variant.$type.versions[$latest.version] = $latest
		Send-Mail $variant $type $latest.version $latest.info1 $latest.info2
	}
	# Store lastCheck
	$db.variant.$variant.$type.lastCheck = @{
		datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
		version  = $latest.version
	}
}

function Get-LatestJava ($type) {
	# Resolve latest version
	$uri = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
	$versionsJson = Invoke-RestMethod -Uri $uri
	$version = $versionsJson.latest.$type

	# Get download URL
	$versionsJsonVersion = $versionsJson.versions | Where-Object { $_.id -eq $version }
	$versionJsonUrl = $versionsJsonVersion.url
	$versionJson = Invoke-RestMethod $versionJsonUrl
	$clientUrl = $versionJson.downloads.client.url
	$serverUrl = $versionJson.downloads.server.url
	
	if (-not $version) { return $false }
	@{
		version  = $version
		info1    = "Client jar: $clientUrl"
		info2    = "Server jar: $serverUrl"
		datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
	}
}

function Get-LatestBedrock {
	$uri = 'https://www.minecraft.net/en-us/download/server/bedrock'
	$userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.0.0 Safari/537.36'
	$headers = @{'Accept' = '*/*'; 'Accept-Encoding' = 'identity'; 'Accept-Language' = 'en'; }
	$content = (Invoke-WebRequest -Uri $uri -UserAgent $userAgent -Headers $headers -TimeoutSec 5).Content
	$version = ($content | Select-String '/bedrock-server-(?<version>.*).zip"').Matches[0].Groups['version'].Value
	$windowsServerUrl = ($content | Select-String 'https.*/bin-win/bedrock-server.*\.zip').Matches.Value
	$linuxServerUrl = ($content | Select-String 'https.*/bin-linux/bedrock-server.*\.zip').Matches.Value

	if (-not $version) { return $false }
	@{
		version  = $version
		info1    = "Windows Server: $windowsServerUrl"
		info2    = "Linux Server: $linuxServerUrl"
		datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
	}
}

function Send-Mail ($variant, $type, $version, $info1, $info2) {
	$variant = (Get-Culture).TextInfo.ToTitleCase($variant)
	$subject = "New Minecraft $variant $type version $version"
	$body = "Minecraft $variant $type version $version has been released.`n"
	$body += "$info1`n"
	$body += "$info2`n"
	$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
	$SMTPClient.EnableSsl = $true
	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPass)
	$SMTPClient.Send($EmailFrom, $EmailTo, $subject, $body)
}

Main
