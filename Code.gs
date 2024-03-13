function main() {
  var scriptProperties = PropertiesService.getScriptProperties()

  // Load versions
  versions = { java: {}, bedrock: {} }
  versions.java.release = JSON.parse(scriptProperties.getProperty("JavaReleaseVersions")) || []
  versions.java.snapshot = JSON.parse(scriptProperties.getProperty("JavaSnapshotVersions")) || []
  versions.bedrock.release = JSON.parse(scriptProperties.getProperty("BedrockReleaseVersions")) || []
  versions.bedrock.preview = JSON.parse(scriptProperties.getProperty("BedrockPreviewVersions")) || []

  checkForUpdates("java", "release")
  checkForUpdates("java", "snapshot")
  checkForUpdates("bedrock", "release")
  checkForUpdates("bedrock", "preview")

  // Store versions
  scriptProperties.setProperty("JavaReleaseVersions", JSON.stringify(versions.java.release))
  scriptProperties.setProperty("JavaSnapshotVersions", JSON.stringify(versions.java.snapshot))
  scriptProperties.setProperty("BedrockReleaseVersions", JSON.stringify(versions.bedrock.release))
  scriptProperties.setProperty("BedrockPreviewVersions", JSON.stringify(versions.bedrock.preview))
}

function checkForUpdates(variant, type) {
  var latest = getLatest(variant, type)
  if (!versions[variant][type].includes(latest.version)) {
    Logger.log(`New ${variant} ${type} version ${latest.version}`)
    versions[variant][type].push(latest.version)
    trimArray(versions[variant][type], 3)
    sendMail(latest)
  }
}

function getLatest(variant, type) {
  if (variant == "java") return getLatestJava(type)
  if (variant == "bedrock") return getLatestBedrock(type)
}

function getLatestJava(type) {
  const url = "https://launchermeta.mojang.com/mc/game/version_manifest.json"
  const response = UrlFetchApp.fetch(url)
  return {
    variant: "java",
    type: type,
    version: JSON.parse(response.getContentText()).latest[type],
  }
}

function getLatestBedrock(type) {
  const url = "https://www.minecraft.net/en-us/download/server/bedrock"
  const response = UrlFetchApp.fetch(url)
  const html = response.getContentText()
  var re = 'href="https://minecraft\.azureedge\.net/bin-win/bedrock-server-(.*)\.zip"'
  if (type == "preview") re = 'href="https://minecraft\.azureedge\.net/bin-win-preview/bedrock-server-(.*)\.zip"'
  return {
    variant: "bedrock",
    type: type,
    version: html.match(re)[1]
  }
}

function trimArray(array, length) {
  while (array.length > length) {
    array.shift()
  }
}

function sendMail(newVersion) {
  var fromName = "Minecraft Version Updates"
  var to = "Minecraft Version Updates <minecraft-version-updates@googlegroups.com>"
  var subject = `New Minecraft ${firstToUpper(newVersion.variant)} ${newVersion.type} version ${newVersion.version}`
  var body = `Minecraft ${firstToUpper(newVersion.variant)} ${newVersion.type} version ${newVersion.version} has been released.`
  MailApp.sendEmail(to, subject, body, { name: fromName })
}

function firstToUpper(string) {
  return string.substr(0, 1).toUpperCase() + string.substr(1)
}
