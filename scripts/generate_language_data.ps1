param(
  [string]$AppTextsPath = "lib/core/app_texts.dart",
  [string]$OutputPath = "lib/core/generated_language_data.dart"
)

$ErrorActionPreference = 'Stop'

function ConvertFrom-DartLiteral([string]$value) {
  return $value.Replace("\'", "'").Replace('\\n', "`n").Replace('\\', '\\')
}

function ConvertTo-DartLiteral([string]$value) {
  return $value.Replace('\\', '\\\\').Replace("'", "\\'").Replace("`r", '').Replace("`n", '\\n')
}

function ConvertTo-LocalizedInteger([string]$value) {
  $buffer = ''
  foreach ($char in $value.ToCharArray()) {
    $numeric = [int][char]::GetNumericValue($char)
    if ($numeric -ge 0) {
      $buffer += $numeric.ToString()
    }
  }

  if ([string]::IsNullOrWhiteSpace($buffer)) {
    throw "Unable to parse localized integer: $value"
  }

  return [int]$buffer
}

function Get-EnglishMap([string[]]$lines) {
  $start = ($lines | Select-String -Pattern 'static const Map<String, String> _en = \{' | Select-Object -First 1).LineNumber
  $end = ($lines | Select-String -Pattern '// All 40 languages - each inherits from EN' | Select-Object -First 1).LineNumber
  if (-not $start -or -not $end) {
    throw 'Could not locate _en map boundaries.'
  }

  $pairs = [ordered]@{}
  for ($i = $start; $i -lt ($end - 1); $i++) {
    $line = $lines[$i]
    $singleLineMatch = [regex]::Match($line, "^\s*'([^']+)':\s*'(.*)',\s*$")
    if ($singleLineMatch.Success) {
      $pairs[$singleLineMatch.Groups[1].Value] = ConvertFrom-DartLiteral $singleLineMatch.Groups[2].Value
      continue
    }

    $multiLineStartMatch = [regex]::Match($line, "^\s*'([^']+)':\s*$")
    if ($multiLineStartMatch.Success) {
      $key = $multiLineStartMatch.Groups[1].Value
      $buffer = ''
      while ($true) {
        $i++
        if ($i -ge ($end - 1)) {
          throw "Unterminated multiline string for key $key"
        }
        $next = $lines[$i]
        $multiLineValueMatch = [regex]::Match($next, "^\s*'(.*)'[,]?\s*$")
        if ($multiLineValueMatch.Success) {
          $buffer += $multiLineValueMatch.Groups[1].Value
          if ($next.TrimEnd().EndsWith("',") -or $next.Trim() -eq "'$buffer',") {
            break
          }
          if ($next.TrimEnd().EndsWith("'")) {
            $peek = $lines[$i + 1].Trim()
            if (-not $peek.StartsWith("'")) {
              break
            }
          }
        } else {
          throw "Unexpected multiline content for key ${key}: $next"
        }
      }
      $pairs[$key] = ConvertFrom-DartLiteral $buffer
    }
  }

  return $pairs
}

function Invoke-TranslationChunk([string]$targetLang, [string[]]$texts) {
  if ($texts.Count -eq 1) {
    $single = $texts[0].Replace("`n", '__NSMOKE_NL__')
    $encodedSingle = [uri]::EscapeDataString($single)
    $singleUrl = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$targetLang&dt=t&q=$encodedSingle"
    $singleResponse = Invoke-RestMethod -Uri $singleUrl -Method Get -TimeoutSec 30
    $singleTranslated = (($singleResponse[0] | ForEach-Object { $_[0] }) -join '')
    return @($singleTranslated.Replace('__NSMOKE_NL__', "`n").Trim())
  }

  $prepared = for ($index = 0; $index -lt $texts.Count; $index++) {
    "[$index] " + $texts[$index].Replace("`n", '__NSMOKE_NL__')
  }
  $joined = [string]::Join(' ', $prepared)
  $encoded = [uri]::EscapeDataString($joined)
  $url = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl=$targetLang&dt=t&q=$encoded"
  $response = Invoke-RestMethod -Uri $url -Method Get -TimeoutSec 30
  $translatedJoined = (($response[0] | ForEach-Object { $_[0] }) -join '')
  $translationItems = [regex]::Matches($translatedJoined, '\[(\d+)\]\s*(.*?)(?=\s*\[\d+\]|$)')
  if ($translationItems.Count -ne $texts.Count) {
    throw "Split mismatch for $targetLang. Expected $($texts.Count), got $($translationItems.Count)."
  }

  $ordered = New-Object string[] $texts.Count
  foreach ($match in $translationItems) {
    $slot = ConvertTo-LocalizedInteger $match.Groups[1].Value
    $ordered[$slot] = $match.Groups[2].Value.Replace('__NSMOKE_NL__', "`n").Trim()
  }

  return $ordered
}

function Invoke-TranslationRecursive([string]$targetLang, [string[]]$texts) {
  try {
    return Invoke-TranslationChunk -targetLang $targetLang -texts $texts
  } catch {
    if ($texts.Count -le 1) {
      throw
    }

    $mid = [Math]::Floor($texts.Count / 2)
    $left = @($texts[0..($mid - 1)])
    $right = @($texts[$mid..($texts.Count - 1)])
    $leftResult = Invoke-TranslationRecursive -targetLang $targetLang -texts $left
    $rightResult = Invoke-TranslationRecursive -targetLang $targetLang -texts $right
    return @($leftResult + $rightResult)
  }
}

function Save-OutputFile(
  [string]$path,
  [string[]]$orderedLanguages,
  [hashtable]$translationsByLanguage,
  [string[]]$keys
) {
  $lines = New-Object System.Collections.Generic.List[string]
  $lines.Add('const Map<String, Map<String, String>> generatedLanguageData = <String, Map<String, String>>{')
  foreach ($lang in $orderedLanguages) {
    if (-not $translationsByLanguage.ContainsKey($lang)) {
      continue
    }
    $map = $translationsByLanguage[$lang]
    $lines.Add("  '$lang': <String, String>{")
    foreach ($key in $keys) {
      $escapedValue = ConvertTo-DartLiteral $map[$key]
      $lines.Add("    '$key': '$escapedValue',")
    }
    $lines.Add('  },')
  }
  $lines.Add('};')
  Set-Content -Path $path -Value $lines -Encoding UTF8
}

function Get-ExistingLanguageMap([string]$path) {
  $result = @{}
  if (-not (Test-Path $path)) {
    return $result
  }

  $lines = Get-Content -Path $path
  $currentLang = $null
  $currentMap = $null
  foreach ($line in $lines) {
    $langStartMatch = [regex]::Match($line, "^\s*'([^']+)': <String, String>\{$")
    if ($langStartMatch.Success) {
      $currentLang = $langStartMatch.Groups[1].Value
      $currentMap = [ordered]@{}
      continue
    }
    $langValueMatch = [regex]::Match($line, "^\s*'([^']+)': '(.*)',\s*$")
    if ($currentLang -and $langValueMatch.Success) {
      $currentMap[$langValueMatch.Groups[1].Value] = ConvertFrom-DartLiteral $langValueMatch.Groups[2].Value
      continue
    }
    if ($currentLang -and $line -match '^\s*\},\s*$') {
      $result[$currentLang] = $currentMap
      $currentLang = $null
      $currentMap = $null
    }
  }

  return $result
}

$lines = Get-Content -Path $AppTextsPath
$englishMap = Get-EnglishMap -lines $lines
$keys = @($englishMap.Keys)
$values = @($englishMap.Values)

$languages = @(
  'de','ar','fr','es','pt','it','pl','ru','ja','zh','ko','hi','bn','pa','te',
  'mr','ta','gu','kn','ml','th','vi','id','ms','fil','uk','ro','el','hu','cs',
  'sv','da','no','fi','nl','be','sr','hr'
)

$batchSize = 8
$translationsByLanguage = Get-ExistingLanguageMap -path $OutputPath

foreach ($lang in $languages) {
  if ($translationsByLanguage.ContainsKey($lang)) {
    Write-Output "Skipping $lang, already generated."
    continue
  }

  Write-Output "Generating $lang translations..."
  $translatedByKey = [ordered]@{}
  for ($offset = 0; $offset -lt $values.Count; $offset += $batchSize) {
    $upper = [Math]::Min($offset + $batchSize - 1, $values.Count - 1)
    $batchValues = @($values[$offset..$upper])
    $batchKeys = @($keys[$offset..$upper])
    $translatedValues = Invoke-TranslationRecursive -targetLang $lang -texts $batchValues
    for ($index = 0; $index -lt $batchKeys.Count; $index++) {
      $translatedByKey[$batchKeys[$index]] = $translatedValues[$index]
    }
  }

  $translationsByLanguage[$lang] = $translatedByKey
  Save-OutputFile -path $OutputPath -orderedLanguages $languages -translationsByLanguage $translationsByLanguage -keys $keys
  Write-Output "Saved $lang translations."
}

Write-Output "Generated $OutputPath"
