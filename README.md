# Helm Charts

Community-maintained Helm charts for Kubernetes applications, maintained by
[Nico Smuts](https://github.com/nicosmuts).

This repository is **OCI-first**. Released charts will be published beneath
`oci://ghcr.io/nicosmuts/charts`; it does not use a Helm repository
`index.yaml` or GitHub Pages.

> No charts have been released yet. Chart source may be available before its
> first OCI release.

## Planned charts

| Chart | Status |
| --- | --- |
| [`braiins-pool-exporter`](charts/braiins-pool-exporter) | Source available; not released |
| `avalonhome-prometheus-exporter` | Planned |
| `open-balena` | Planned |
| `assetto-corsa-server-manager` | Planned |

## Future installation

After a chart version has been published, install it directly from GHCR:

```console
helm install braiins-pool-exporter \
  oci://ghcr.io/nicosmuts/charts/braiins-pool-exporter \
  --version <chart-version>
```

Helm 3 is required. Kubernetes version support will be declared by each chart.

## Development

The repository supports PowerShell directly:

```powershell
./scripts/helm-charts.ps1 verify
./scripts/helm-charts.ps1 package
```

Where `make` is available, equivalent targets include `make lint`,
`make template`, `make test`, `make package`, and `make verify`. All commands
exit successfully with an informative message while no charts exist.

See [development guidance](docs/DEVELOPMENT.md), the
[chart standard](docs/CHART_STANDARD.md), and
[publishing guidance](docs/PUBLISHING.md).

## Contributing and security

Contributions are welcome; read [CONTRIBUTING.md](CONTRIBUTING.md) before
opening a pull request. Report vulnerabilities according to
[SECURITY.md](SECURITY.md), not in a public issue.

Charts in this repository must remain reusable and public. Cluster-specific
values, private hosts, credentials, Argo CD Applications, and other environment
configuration belong in a separate private GitOps repository.

## License

This repository is licensed under the [MIT License](LICENSE). A chart may
package or integrate software under a different license; its metadata and
documentation must identify that upstream license.
