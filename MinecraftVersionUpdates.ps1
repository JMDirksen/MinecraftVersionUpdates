# Include config
$configFile = "$PSScriptRoot\MinecraftVersionUpdates.config.ps1"
if (Test-Path $configFile) { . $configFile }
else { "Config file MinecraftVersionUpdates.config.ps1 not found"; exit }

# Mojang urls
$versionsJsonUrl = "https://launchermeta.mojang.com/mc/game/version_manifest.json"

$dbFile = "$PSScriptRoot\MinecraftVersionUpdates.json"

function Main {
	Open-Db
	
	Invoke-CheckJavaVersion "release"
	Invoke-CheckJavaVersion "snapshot"

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
	}
}

function Save-Db {
	$db | ConvertTo-Json -Depth 10 | Out-File $dbFile
}

function Invoke-CheckJavaVersion ($type) {
	$latestJava = Get-LatestJava -type $type
	# New version
	if ($latestJava.version -ne $db.variant.java.$type.lastCheck.version) {
		"New version " + $latestJava.version
		# Store version
		$db.variant.java.$type.versions[$latestJava.version] = $latestJava
		Send-Mail $type $latestJava.version $latestJava.clientUrl $latestJava.serverUrl
	}
	# Store lastCheck
	$db.variant.java.$type.lastCheck = @{
		datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
		version  = $latestJava.version
	}
}

function Get-LatestJava ($type) {
	# Resolve latest version
	$versionsJson = Invoke-RestMethod $versionsJsonUrl
	$version = $versionsJson.latest.$type
	
	# Get download URL
	$versionsJsonVersion = $versionsJson.versions | Where-Object { $_.id -eq $version }
	$versionJsonUrl = $versionsJsonVersion.url
	$versionJson = Invoke-RestMethod $versionJsonUrl
	$clientUrl = $versionJson.downloads.client.url
	$serverUrl = $versionJson.downloads.server.url
	
	@{
		version   = $version
		clientUrl = $clientUrl
		serverUrl = $serverUrl
		datetime  = Get-Date -Format "yyyy-MM-dd HH:mm"
	}
}

function Send-Mail ($type, $version, $clientUrl, $serverUrl) {
	$subject = "New Minecraft Java $type version $version"
	$body = "Minecraft Java $type version $version has been released.`n"
	$body += "Client jar: $clientUrl`n"
	$body += "Server jar: $serverUrl`n"
	$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
	$SMTPClient.EnableSsl = $true
	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPass)
	$SMTPClient.Send($EmailFrom, $EmailTo, $subject, $body)
}

Main
