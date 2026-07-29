[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet("help", "lint", "template", "test", "package", "verify", "clean")]
    [string]$Command = "help"
)

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path -Parent $PSScriptRoot
$ChartsRoot = Join-Path $RepoRoot "charts"
$DistRoot = Join-Path $RepoRoot "dist"

function Get-Charts {
    if (-not (Test-Path -LiteralPath $ChartsRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $ChartsRoot -Directory |
        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName "Chart.yaml") })
}

function Get-CIValues([System.IO.DirectoryInfo]$Chart) {
    $ciRoot = Join-Path $Chart.FullName "ci"
    if (-not (Test-Path -LiteralPath $ciRoot)) {
        return @()
    }
    return @(Get-ChildItem -LiteralPath $ciRoot -File -Filter "*-values.yaml" |
        Sort-Object Name)
}

function Assert-Command([string]$Name) {
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "Required command '$Name' was not found in PATH."
    }
}

function Invoke-Lint {
    $charts = @(Get-Charts)
    if ($charts.Count -eq 0) {
        Write-Host "lint: no charts found; nothing to do."
        return
    }
    Assert-Command "helm"
    foreach ($chart in $charts) {
        & helm lint --strict $chart.FullName
        if ($LASTEXITCODE -ne 0) { throw "helm lint failed for $($chart.Name)." }
        foreach ($values in @(Get-CIValues $chart)) {
            & helm lint --strict $chart.FullName --values $values.FullName
            if ($LASTEXITCODE -ne 0) {
                throw "helm lint failed for $($chart.Name) with $($values.Name)."
            }
        }
    }
}

function Invoke-Template {
    $charts = @(Get-Charts)
    if ($charts.Count -eq 0) {
        Write-Host "template: no charts found; nothing to do."
        return
    }
    Assert-Command "helm"
    foreach ($chart in $charts) {
        $ciValues = @(Get-CIValues $chart)
        if ($ciValues.Count -eq 0) {
            $ciValues = @($null)
        }
        foreach ($values in $ciValues) {
            $arguments = @("template", $chart.Name, $chart.FullName)
            $label = "defaults"
            if ($null -ne $values) {
                $arguments += @("--values", $values.FullName)
                $label = $values.Name
            }
            & helm @arguments *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "helm template failed for $($chart.Name) with $label."
            }
            Write-Host "template: rendered $($chart.Name) with $label."
        }
    }
}

function Invoke-Test {
    $charts = @(Get-Charts)
    if ($charts.Count -eq 0) {
        Write-Host "test: no charts found; nothing to do."
        return
    }
    Assert-Command "helm"
    foreach ($chart in $charts) {
        $previousErrorAction = $ErrorActionPreference
        try {
            $ErrorActionPreference = "Continue"
            & helm template "$($chart.Name)-invalid" $chart.FullName `
                --set "config.historyDays=0" *> $null
            $invalidExitCode = $LASTEXITCODE
        } finally {
            $ErrorActionPreference = $previousErrorAction
        }
        if ($invalidExitCode -eq 0) {
            throw "values.schema.json accepted invalid historyDays for $($chart.Name)."
        }
        Write-Host "test: schema rejected invalid values for $($chart.Name)."
        $global:LASTEXITCODE = 0
    }
    Write-Host "test: static chart tests passed (Helm hooks run after installation)."
}

function Invoke-Package {
    $charts = @(Get-Charts)
    if ($charts.Count -eq 0) {
        Write-Host "package: no charts found; nothing to do."
        return
    }
    Assert-Command "helm"
    New-Item -ItemType Directory -Force -Path $DistRoot | Out-Null
    foreach ($chart in $charts) {
        & helm package $chart.FullName --destination $DistRoot
        if ($LASTEXITCODE -ne 0) { throw "helm package failed for $($chart.Name)." }
    }
}

function Invoke-StructureChecks {
    $forbidden = @(
        Get-ChildItem -LiteralPath $RepoRoot -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notlike "$RepoRoot\.git\*" -and
                $_.FullName -notlike "$DistRoot\*" -and
                $_.FullName -notlike "$(Join-Path $RepoRoot "build")\*" -and
                (
                $_.Extension -eq ".tgz" -or
                $_.Name -eq "index.yaml" -or
                $_.Name -match "^(kubeconfig|registry\.json|repositories\.yaml)$"
                )
            }
    )
    if ($forbidden.Count -gt 0) {
        throw "Forbidden artifacts found: $($forbidden.FullName -join ', ')"
    }

    foreach ($chart in @(Get-Charts)) {
        foreach ($required in @("Chart.yaml", "values.yaml", "values.schema.json", "README.md", "templates")) {
            if (-not (Test-Path -LiteralPath (Join-Path $chart.FullName $required))) {
                throw "$($chart.Name) is missing required path '$required'."
            }
        }
    }
    Write-Host "structure: repository checks passed."
}

function Invoke-Verify {
    Invoke-StructureChecks
    Invoke-Lint
    Invoke-Template
    Invoke-Test
    Write-Host "verify: all available checks passed."
}

switch ($Command) {
    "help" {
        Write-Host @"
Helm chart repository commands:
  help      Show this help
  lint      Run strict Helm linting
  template  Render every chart with CI values
  test      Run static chart tests
  package   Package charts into ./dist
  verify    Run structure, lint, render, and test checks
  clean     Remove the local ./dist directory
"@
    }
    "lint" { Invoke-Lint }
    "template" { Invoke-Template }
    "test" { Invoke-Test }
    "package" { Invoke-Package }
    "verify" { Invoke-Verify }
    "clean" {
        if (Test-Path -LiteralPath $DistRoot) {
            Remove-Item -LiteralPath $DistRoot -Recurse -Force
        }
        Write-Host "clean: removed local build artifacts."
    }
}
