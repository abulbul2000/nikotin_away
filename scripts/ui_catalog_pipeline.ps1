param(
  [Parameter(Mandatory = $true)]
  [ValidateSet('capture', 'apply-feedback')]
  [string]$Mode,

  [string]$DeviceId = 'emulator-5554',
  [string]$CatalogRoot = 'ui_catalog',
  [string]$FeedbackFile = ''
)

$ErrorActionPreference = 'Stop'

function Write-CatalogSystemReport {
  param(
    [Parameter(Mandatory = $true)]
    [string]$CatalogRootPath
  )

  $projectRoot = (Get-Location).Path
  $catalogRootAbs = if ([System.IO.Path]::IsPathRooted($CatalogRootPath)) {
    $CatalogRootPath
  }
  else {
    Join-Path $projectRoot $CatalogRootPath
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

  $pageFiles = @()
  $pagesRoot = Join-Path $projectRoot 'lib/pages'
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
    $rel = "lib/pages/$($pageFile.Name)"
    $relNormalized = $rel.Replace('\\', '/')
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
    $systemReportPath
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
}

function Start-CatalogCapture {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param(
    [Parameter(Mandatory = $true)]
    [string]$DeviceId,

    [Parameter(Mandatory = $true)]
    [string]$CatalogRoot
  )

  if ($PSCmdlet.ShouldProcess("device $DeviceId", 'capture UI catalog')) {
    & C:\flutter\bin\flutter.bat pub get
    if ($LASTEXITCODE -ne 0) {
      throw 'flutter pub get failed'
    }

    & C:\flutter\bin\flutter.bat drive `
      --driver=test_driver/ui_catalog_driver.dart `
      --target=integration_test/ui_catalog_capture_test.dart `
      -d $DeviceId `
      --dart-define=UI_CATALOG_ROOT=$CatalogRoot

    if ($LASTEXITCODE -ne 0) {
      throw 'ui catalog capture failed'
    }

    Write-Output "Capture complete."
    Write-Output "Screen folder: $CatalogRoot/screens"
    Write-Output "Catalog JSON: $CatalogRoot/catalog/screen_catalog.json"
    Write-Output "Catalog MD: $CatalogRoot/catalog/screen_catalog.md"
    Write-Output "Capture report: $CatalogRoot/reports/last_capture_report.json"
    Write-CatalogSystemReport -CatalogRootPath $CatalogRoot
  }
}

if ($Mode -eq 'capture') {
  Start-CatalogCapture -DeviceId $DeviceId -CatalogRoot $CatalogRoot
  exit 0
}

if ([string]::IsNullOrWhiteSpace($FeedbackFile)) {
  throw 'FeedbackFile is required for apply-feedback mode'
}

if (!(Test-Path $FeedbackFile)) {
  throw "Feedback file not found: $FeedbackFile"
}

$catalogJson = Join-Path $CatalogRoot 'catalog/screen_catalog.json'
if (!(Test-Path $catalogJson)) {
  throw "Catalog file not found: $catalogJson. Run capture mode first."
}

& C:\flutter\bin\dart.bat run tool/apply_ui_feedback.dart $catalogJson $FeedbackFile
if ($LASTEXITCODE -ne 0) {
  throw 'Applying feedback failed'
}

Start-CatalogCapture -DeviceId $DeviceId -CatalogRoot $CatalogRoot

$applyReportPath = Join-Path $CatalogRoot 'reports/last_feedback_apply_report.json'
$captureReportPath = Join-Path $CatalogRoot 'reports/last_capture_report.json'
$finalReportPath = Join-Path $CatalogRoot 'reports/last_feedback_run_report.json'

$applyReport = $null
$captureReport = $null
if (Test-Path $applyReportPath) {
  $applyReport = Get-Content -Raw $applyReportPath | ConvertFrom-Json
}
if (Test-Path $captureReportPath) {
  $captureReport = Get-Content -Raw $captureReportPath | ConvertFrom-Json
}

$finalReport = [ordered]@{
  generatedAt = (Get-Date).ToString('o')
  updatedScreenIds = @($applyReport.updatedScreenIds)
  changedFiles = @($applyReport.changedFiles)
  newScreenshots = @($applyReport.updatedScreenshots)
  newScreenFolder = if ($captureReport) { $captureReport.screenFolder } else { "$CatalogRoot/screens" }
  catalogJson = if ($captureReport) { $captureReport.catalogJson } else { "$CatalogRoot/catalog/screen_catalog.json" }
  catalogMarkdown = if ($captureReport) { $captureReport.catalogMarkdown } else { "$CatalogRoot/catalog/screen_catalog.md" }
  applyReport = $applyReportPath
  captureReport = $captureReportPath
}

$finalReport | ConvertTo-Json -Depth 6 | Set-Content -Path $finalReportPath -Encoding UTF8

Write-Output "Feedback apply + recapture complete."
Write-Output "Apply report: $applyReportPath"
Write-Output "Final run report: $finalReportPath"
