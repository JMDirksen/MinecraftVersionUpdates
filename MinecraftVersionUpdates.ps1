# Include config
$configFile = "$PSScriptRoot\MinecraftVersionUpdates.config.ps1"
if (Test-Path $configFile) { . $configFile }
else { "Config file MinecraftVersionUpdates.config.ps1 not found"; exit }

# Mojang urls
$versionsJsonUrl = "https://launchermeta.mojang.com/mc/game/version_manifest.json"

$dbFile = "MinecraftVersionUpdates.json"

# Load db
$db = Get-Content $dbFile -ErrorAction SilentlyContinue | ConvertFrom-Json -AsHashtable
if ($null -eq $db) {
	$db = @{}
	$db.versions = @{}
}
	
# Resolve latest version
$versionsJson = Invoke-RestMethod $versionsJsonUrl
$version = $versionsJson.latest.release

# New version
if ($version -ne $db.lastCheck.version) {
	"New version $version"

	# Get download URL
	$versionsJsonVersion = $versionsJson.versions | Where-Object { $_.id -eq $version }
	$versionJsonUrl = $versionsJsonVersion.url
	$versionJson = Invoke-RestMethod $versionJsonUrl

	# Store version
	$db.versions[$version] = @{}
	$db.versions[$version].datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
	$db.versions[$version].version = $version
	$db.versions[$version].clientUrl = $versionJson.downloads.client.url
	$db.versions[$version].serverUrl = $versionJson.downloads.server.url

	# Send e-mail
	"Sending E-mail"
	$Subject = "New Minecraft Java release version $version"
	$Body = "Minecraft Java release version $version has been released.`n"
	$Body += "Client jar: " + $versionJson.downloads.client.url + "`n"
	$Body += "Server jar: " + $versionJson.downloads.server.url + "`n"
	$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587)
	$SMTPClient.EnableSsl = $true
	$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($SMTPUser, $SMTPPass)
	$SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)
}

# Store last check
$db.lastCheck = @{}
$db.lastCheck.datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
$db.lastCheck.version = $version

# Save db
$db | ConvertTo-Json | Out-File $dbFile
$db | ConvertTo-Json
