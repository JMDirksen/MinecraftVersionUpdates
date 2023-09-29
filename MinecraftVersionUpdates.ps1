$dbFile = Join-Path $PSScriptRoot "db.xml"

function Main {
	Open-Db
	
	Invoke-CheckVersion 'java' 'release'
	Invoke-CheckVersion 'java' 'snapshot'
	Invoke-CheckVersion 'bedrock' 'release'

	Save-Db
}

function Open-Db {
	# Read db
	try {
		$Global:db = Import-Clixml $dbFile
	}

	# New db
	catch {
		$Global:db = @{
			variant = @{
				bedrock = @{release = @{versions = @{} } }
				java    = @{
					snapshot = @{versions = @{} }
					release  = @{versions = @{} }
				}
			}
			email = @{
				from = Read-Host "From"
				to = Read-Host "To"
				server = Read-Host "Server"
				port = Read-Host "Port"
				usessl = $true
				credential = Get-Credential
			}
		}
	}
}

function Save-Db {
	$db | Export-Clixml $dbFile
}

function Invoke-CheckVersion ($variant, $type) {
	if ($variant -eq 'java') { $latest = Get-LatestJava -type $type }
	if ($variant -eq 'bedrock') { $latest = Get-LatestBedrock }
	if (-not $latest) { return $false }
	
	# New version
	if ($latest.version -ne $db.variant.$variant.$type.lastCheck.version -and -not $db.variant.$variant.$type.versions[$latest.version]) {
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
	$headers = @{'Accept-Language' = '*' }
	$links = (Invoke-WebRequest -Uri $uri -Headers $headers -TimeoutSec 5).Links
	$windowsUrl = ($links | Where-Object { $_.href -like "*/bin-win/bedrock-server-*" }).href
	$linuxUrl = ($links | Where-Object { $_.href -like "*/bin-linux/bedrock-server-*" }).href
	$version = ($linuxUrl | Select-String 'server-(?<ver>.*).zip').Matches[0].Groups['ver'].Value
	
	if (-not $version) { return $false }
	@{
		version  = $version
		info1    = "Windows Server: $windowsUrl"
		info2    = "Linux Server: $linuxUrl"
		datetime = Get-Date -Format "yyyy-MM-dd HH:mm"
	}
}

function Send-Mail ($variant, $type, $version, $info1, $info2) {
	$variant = (Get-Culture).TextInfo.ToTitleCase($variant)
	$subject = "New Minecraft $variant $type version $version"
	$body = "Minecraft $variant $type version $version has been released.`n"
	$body += "$info1`n"
	$body += "$info2`n"

	$params = @{
		From = $db.email.from
		To = $db.email.to
		Subject = $subject
		Body = $body
		BodyAsHtml = $true
		SmtpServer = $db.email.server
		Port = $db.email.port
		UseSsl = $db.email.usessl
		Credential = $db.email.credential
	}
	Send-MailMessage @params
}

Main
