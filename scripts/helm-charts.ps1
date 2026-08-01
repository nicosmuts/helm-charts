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

        if ($chart.Name -eq "avalonhome-prometheus-exporter") {
            Invoke-AvalonHomeStaticTests $chart
        }
    }
    Write-Host "test: static chart tests passed (Helm hooks run after installation)."
}

function Invoke-HelmTemplate([System.IO.DirectoryInfo]$Chart, [string[]]$Arguments) {
    $output = & helm template $Chart.Name $Chart.FullName @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "helm template failed for $($Chart.Name) static assertion."
    }
    return ($output -join "`n")
}

function Assert-Contains([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -notmatch $Pattern) {
        throw $Message
    }
}

function Assert-NotContains([string]$Text, [string]$Pattern, [string]$Message) {
    if ($Text -match $Pattern) {
        throw $Message
    }
}

function Assert-HelmRejects([System.IO.DirectoryInfo]$Chart, [string[]]$Arguments, [string]$Message) {
    $previousErrorAction = $ErrorActionPreference
    try {
        $ErrorActionPreference = "Continue"
        & helm template "$($Chart.Name)-invalid" $Chart.FullName @Arguments *> $null
        $invalidExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }
    if ($invalidExitCode -eq 0) {
        throw $Message
    }
    $global:LASTEXITCODE = 0
}

function Assert-HelmRejectsValues([System.IO.DirectoryInfo]$Chart, [string]$Values, [string]$Message) {
    $tempFile = New-TemporaryFile
    try {
        Set-Content -LiteralPath $tempFile.FullName -Value $Values -NoNewline
        Assert-HelmRejects $Chart @("--values", $tempFile.FullName) $Message
    } finally {
        Remove-Item -LiteralPath $tempFile.FullName -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-AvalonHomeStaticTests([System.IO.DirectoryInfo]$Chart) {
    $default = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/default-values.yaml"))
    Assert-Contains $default 'image: "ghcr\.io/brav0charlie/avalonhome-prometheus-exporter:v0\.4\.0"' "default image tag was not rendered."
    Assert-Contains $default 'name: AVALON_IP\s+value: "192\.168\.1\.50"' "single-miner AVALON_IP was not rendered."
    Assert-NotContains $default 'name: AVALON_IPS' "single-miner render unexpectedly set AVALON_IPS."
    Assert-Contains $default 'name: AVALON_PORT\s+value: "4028"' "miner API port was not rendered."
    Assert-Contains $default 'name: EXPORTER_PORT\s+value: "9100"' "exporter port was not rendered."
    Assert-Contains $default 'path: /health\s+port: http' "health probes do not use /health."
    Assert-NotContains $default '(?m)^kind: (Secret|Role|RoleBinding|ClusterRole|ClusterRoleBinding)$' "chart rendered forbidden Secret or RBAC resources."
    Assert-Contains $default 'runAsNonRoot: true' "secure non-root defaults were not rendered."
    Assert-Contains $default 'readOnlyRootFilesystem: true' "read-only root filesystem was not rendered."
    Assert-Contains $default 'automountServiceAccountToken: false' "ServiceAccount token automount was not disabled."

    $multi = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/multi-miner-values.yaml"))
    Assert-Contains $multi 'name: AVALON_IPS\s+value: "nano3s-01\.local,mini3-rack1\.lan,192\.168\.1\.99"' "multi-miner AVALON_IPS was not rendered as comma-separated hosts."
    Assert-NotContains $multi 'name: AVALON_IP\s+value:' "multi-miner render unexpectedly set AVALON_IP."

    $digest = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/digest-values.yaml"))
    Assert-Contains $digest 'image: "ghcr\.io/brav0charlie/avalonhome-prometheus-exporter@sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"' "digest did not take precedence over image tag."

    $monitoring = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/monitoring-values.yaml"))
    Assert-Contains $monitoring '(?m)^kind: ServiceMonitor$' "ServiceMonitor was not rendered."
    Assert-Contains $monitoring 'path: /metrics' "ServiceMonitor did not use /metrics."
    Assert-Contains $monitoring 'port: http' "ServiceMonitor did not target the http port."

    $networkPolicy = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/networkpolicy-values.yaml"))
    Assert-Contains $networkPolicy '(?m)^kind: NetworkPolicy$' "NetworkPolicy was not rendered."
    Assert-Contains $networkPolicy 'policyTypes:\s+- Ingress\s+- Egress' "NetworkPolicy did not include requested policy types."
    Assert-Contains $networkPolicy 'port: 4028' "NetworkPolicy egress fixture did not render miner API port."

    $scheduling = Invoke-HelmTemplate $Chart @("--values", (Join-Path $Chart.FullName "ci/scheduling-values.yaml"))
    Assert-Contains $scheduling '(?m)^kind: PodDisruptionBudget$' "PodDisruptionBudget was not rendered."
    Assert-Contains $scheduling 'nodeSelector:\s+kubernetes\.io/os: linux' "nodeSelector fixture was not rendered."
    Assert-Contains $scheduling 'topologySpreadConstraints:' "topology spread constraints were not rendered."

    Assert-HelmRejectsValues $Chart "config:`n  avalonIP: `"`"`n  avalonIPs: []`n" "schema accepted missing miner targets."
    Assert-HelmRejectsValues $Chart "config:`n  avalonIP: one`n  avalonIPs:`n    - two`n" "schema accepted both AVALON_IP and AVALON_IPS."
    Assert-HelmRejects $Chart @("--set", "config.updateInterval=0") "schema accepted zero updateInterval."
    Assert-HelmRejects $Chart @("--set", "config.avalonPort=0") "schema accepted invalid miner port."
    Assert-HelmRejects $Chart @("--set", "image.tag=latest") "schema accepted latest image tag."
    Assert-HelmRejects $Chart @("--set", "commonLabels.app\.kubernetes\.io/name=override") "schema accepted reserved selector label."

    Write-Host "test: avalonhome-prometheus-exporter static assertions passed."
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
