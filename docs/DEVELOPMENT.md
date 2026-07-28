# Development

## Tools

Required:

- Git
- Helm 3
- PowerShell 5.1 or later (PowerShell 7 is recommended)

Optional CI-parity tools include `yamllint`, `actionlint`, `chart-testing`, and
GNU Make. Docker is needed only for local registry or cluster testing.

## Adding a chart

1. Create `charts/<chart-name>` using the layout in
   [CHART_STANDARD.md](CHART_STANDARD.md).
2. Define metadata, defaults, and a complete JSON schema.
3. Implement templates with secure defaults and generic values.
4. Add `ci/default-values.yaml` plus additional branch-coverage value files.
5. Document installation, configuration, compatibility, and limitations.
6. Run the verification commands before opening a pull request.

Do not add private hosts, IP addresses, tokens, Secrets, kubeconfigs, or
environment-specific scheduling.

## Commands

On Windows:

```powershell
./scripts/helm-charts.ps1 lint
./scripts/helm-charts.ps1 template
./scripts/helm-charts.ps1 test
./scripts/helm-charts.ps1 package
./scripts/helm-charts.ps1 verify
```

With Make:

```console
make verify
make package
```

The package command writes ignored artifacts to `dist/`. Commands succeed
cleanly when there are no charts.

## Local OCI testing

For integration work, run a disposable OCI registry and push a packaged chart:

```console
docker run --rm -d -p 5000:5000 --name helm-registry registry:2
helm package charts/<chart-name> --destination dist
helm push dist/<chart-name>-<version>.tgz oci://localhost:5000/charts
```

Use only disposable test credentials and remove the registry afterward. Local
testing must never add credentials or generated packages to Git.
