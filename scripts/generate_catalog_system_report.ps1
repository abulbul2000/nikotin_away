param(
  [string]$CatalogRoot = 'ui_catalog'
)

$ErrorActionPreference = 'Stop'

$projectRoot = (Get-Location).Path
$catalogRootAbs = if ([System.IO.Path]::IsPathRooted($CatalogRoot)) {
  $CatalogRoot
}
else {
  Join-Path $projectRoot $CatalogRoot
}

$catalogJsonPath = Join-Path $catalogRootAbs 'catalog/screen_catalog.json'
$catalogMarkdownPath = Join-Path $catalogRootAbs 'catalog/screen_catalog.md'
$screensDirPath = Join-Path $catalogRootAbs 'screens'
$reportsDirPath = Join-Path $catalogRootAbs 'reports'
$captureReportPath = Join-Path $reportsDirPath 'last_capture_report.json'
$systemReportPath = Join-Path $reportsDirPath 'last_catalog_system_report.json'

if (!(Test-Path $catalogJsonPath)) {
  throw "Catalog file not found: $catalogJsonPath"
}

if (!(Test-Path $reportsDirPath)) {
  New-Item -Path $reportsDirPath -ItemType Directory -Force | Out-Null
}

$catalog = Get-Content -Raw $catalogJsonPath | ConvertFrom-Json
$screens = @($catalog.screens)

$generatedScreens = @()
$notGeneratedFromCatalog = @()
foreach ($screen in $screens) {
  $screenPath = Join-Path $projectRoot $screen.screenshotPath
  if (Test-Path $screenPath) {
    $generatedScreens += $screen
  }
  else {
    $notGeneratedFromCatalog += [ordered]@{
      reason = 'missing_render_output'
      screenId = $screen.screenId
      screenName = $screen.screenName
      expectedPath = $screenPath
    }
  }
}

$pagesRoot = Join-Path $projectRoot 'lib/pages'
$pageFiles = @()
if (Test-Path $pagesRoot) {
  $pageFiles = @(Get-ChildItem -Path $pagesRoot -Filter '*.dart' -File)
}

$catalogedPageRel = New-Object System.Collections.Generic.HashSet[string]
foreach ($screen in $screens) {
  foreach ($sourceFile in @($screen.sourceFiles)) {
    $sourcePath = $sourceFile.ToString()
    if ($sourcePath.StartsWith('lib/pages/', [System.StringComparison]::OrdinalIgnoreCase)) {
      [void]$catalogedPageRel.Add($sourcePath.Replace('\\', '/'))
    }
  }
}

$notGeneratedUncataloged = @()
foreach ($pageFile in $pageFiles) {
  $relNormalized = ("lib/pages/$($pageFile.Name)").Replace('\\', '/')
  if (-not $catalogedPageRel.Contains($relNormalized)) {
    $reason = if ($pageFile.Length -eq 0) { 'page_file_empty' } else { 'not_cataloged' }
    $notGeneratedUncataloged += [ordered]@{
      reason = $reason
      screenId = $null
      screenName = [System.IO.Path]::GetFileNameWithoutExtension($pageFile.Name)
      expectedPath = $pageFile.FullName
    }
  }
}

$notGenerated = @($notGeneratedFromCatalog + $notGeneratedUncataloged)

$helperFiles = @(
  $screensDirPath,
  $catalogJsonPath,
  $catalogMarkdownPath,
  $captureReportPath,
  $systemReportPath,
  (Join-Path $projectRoot 'scripts/ui_catalog_pipeline.ps1'),
  (Join-Path $projectRoot 'scripts/generate_catalog_system_report.ps1'),
  (Join-Path $projectRoot 'tool/apply_ui_feedback.dart'),
  (Join-Path $projectRoot 'tool/find_ui_screen.dart')
)

$report = [ordered]@{
  generatedAt = (Get-Date).ToString('o')
  activeLanguageCode = $catalog.activeLanguageCode
  totalFoundScreens = ($screens.Count + $notGeneratedUncataloged.Count)
  totalGeneratedScreens = $generatedScreens.Count
  notGeneratedScreens = $notGenerated
  screenFolderAbsolutePath = $screensDirPath
  catalogJsonAbsolutePath = $catalogJsonPath
  catalogMarkdownAbsolutePath = $catalogMarkdownPath
  helperFilesAbsolutePaths = $helperFiles
}

$report | ConvertTo-Json -Depth 8 | Set-Content -Path $systemReportPath -Encoding UTF8

Write-Output "Catalog system report: $systemReportPath"
Write-Output "Total found screens: $($report.totalFoundScreens)"
Write-Output "Total generated screens: $($report.totalGeneratedScreens)"
Write-Output "Not generated screens: $($notGenerated.Count)"
