# Braiins Pool Exporter Helm Chart

This chart deploys
[Braiins Pool Exporter](https://github.com/nicosmuts/braiins-pool-exporter),
an independent Prometheus exporter for Braiins Pool account, worker, reward,
and payout metrics.

The upstream `0.0.1` release is an initial public development release. Its
configuration and metric interfaces may change before `0.1.0`.

## Prerequisites

- Helm 3
- Kubernetes 1.25 or later
- An existing Braiins Pool API token Secret for authenticated pool metrics
- Prometheus Operator CRDs only when `serviceMonitor.enabled=true`

The chart starts without credentials and exposes exporter self-metrics. A
token is required for authenticated Braiins Pool API polling.

## Install from the local chart

```console
helm install braiins-pool-exporter \
  ./charts/braiins-pool-exporter \
  --namespace monitoring \
  --create-namespace
```

No chart release has been published yet. After version `0.1.0` is published,
the OCI installation command will be:

```console
helm install braiins-pool-exporter \
  oci://ghcr.io/nicosmuts/charts/braiins-pool-exporter \
  --version 0.1.0 \
  --namespace monitoring \
  --create-namespace
```

## Configure an existing Secret

The chart never creates a Secret. Create one outside Helm and let the exporter
read the token from a mounted file, which is the upstream-recommended
production model:

```console
kubectl --namespace monitoring create secret generic braiins-pool-api-token \
  --from-file=token=/secure/path/to/braiins-pool-token
```

Configure the reference:

```yaml
existingSecret:
  name: braiins-pool-api-token
  key: token
```

The Secret is mounted read-only, and `BRAIINS_POOL_TOKEN_FILE` points to the
mounted token. Do not set `BRAIINS_POOL_TOKEN` through ordinary values because
Helm release state would retain the plaintext value.

## Prometheus Operator integration

Enable the optional ServiceMonitor and add labels selected by your Prometheus
installation:

```yaml
serviceMonitor:
  enabled: true
  labels:
    prometheus: platform
  interval: 30s
  scrapeTimeout: 10s
```

The default endpoint is the Service port named `http` at `/metrics`. If
`config.telemetryPath` is changed, set `serviceMonitor.path` to the same path.
No fixed Prometheus release label is assumed.

## Pin the image by digest

A digest takes precedence over the tag:

```yaml
image:
  digest: sha256:bf72417b08d84e0ae78f331ad57784ef8978f2f63906240153a2795a2dfd8cc3
```

That digest identifies the released `0.0.1` multi-architecture OCI index for
`linux/amd64` and `linux/arm64`.

## Application configuration

The chart maps supported settings to the upstream environment variables and
flags:

```yaml
config:
  pollInterval: 2m
  timeout: 15s
  workerMetricsEnabled: true
  maxWorkers: 250
  rewardsEnabled: true
  payoutsEnabled: true
  historyDays: 14
  logLevel: info
  logFormat: json
```

Only `btc` is accepted by the current application. `config.apiBaseURL` is
intended for tests or compatible endpoints and should normally remain empty so
the official upstream API origin is used.

## NetworkPolicy

NetworkPolicy is disabled by default. To restrict metric ingress to a
monitoring namespace:

```yaml
networkPolicy:
  enabled: true
  ingress:
    allowExternal: false
    from:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: monitoring
```

The default policy governs ingress only. If `Egress` is added to
`networkPolicy.policyTypes`, supply explicit DNS and Braiins API egress rules
appropriate to the cluster; Kubernetes NetworkPolicy cannot select an external
service by DNS name.

## Upgrade and uninstall

Review upstream and chart release notes, then upgrade with an explicit chart
version:

```console
helm upgrade braiins-pool-exporter \
  oci://ghcr.io/nicosmuts/charts/braiins-pool-exporter \
  --version <new-chart-version> \
  --namespace monitoring \
  --reuse-values
```

Prefer a checked values file over `--reuse-values` when defaults or schemas
change. To uninstall:

```console
helm uninstall braiins-pool-exporter --namespace monitoring
```

The external Secret is not deleted by Helm.

## Security

The released image is distroless and runs as UID/GID `65532`. Defaults enforce
non-root execution, RuntimeDefault seccomp, no privilege escalation, all
capabilities dropped, a read-only root filesystem, and no service-account token
mount. The chart creates no RBAC resources and does not use host networking,
host PID, host IPC, or privileged containers.

Worker names are Prometheus labels and may expose internal naming conventions.
Keep the exporter Service private and use NetworkPolicy where appropriate.

No credentials, token examples, wallet data, or private configuration are
bundled in this chart.

## Versioning

Chart `version` tracks Kubernetes packaging changes and follows Semantic
Versioning. `appVersion` tracks the packaged upstream exporter version. They
change independently.

## Values

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `replicaCount` | integer | `1` | Deployment replicas |
| `image.repository` | string | `ghcr.io/nicosmuts/braiins-pool-exporter` | Exporter image repository |
| `image.tag` | string | `0.0.1` | Immutable release tag used when no digest is set |
| `image.digest` | string | `""` | Optional `sha256` image digest; overrides the tag |
| `image.pullPolicy` | string | `IfNotPresent` | Image pull policy |
| `imagePullSecrets` | list | `[]` | Pod image pull Secret references |
| `nameOverride` | string | `""` | Partial resource-name override |
| `fullnameOverride` | string | `""` | Full resource-name override |
| `commonLabels` | object | `{}` | Labels added to chart resources; generated selector labels are reserved |
| `serviceAccount.create` | boolean | `true` | Create a dedicated ServiceAccount |
| `serviceAccount.automountServiceAccountToken` | boolean | `false` | Mount the Kubernetes API token |
| `serviceAccount.annotations` | object | `{}` | ServiceAccount annotations |
| `serviceAccount.labels` | object | `{}` | Additional ServiceAccount labels |
| `serviceAccount.name` | string | `""` | Existing or generated ServiceAccount name |
| `podAnnotations` | object | `{}` | Pod annotations |
| `podLabels` | object | `{}` | Additional non-selector pod labels; generated selector labels are reserved |
| `podSecurityContext` | object | secure defaults | Pod-level security context |
| `containerSecurityContext` | object | secure defaults | Exporter container security context |
| `config.coin` | string | `btc` | Braiins Pool coin; only `btc` is supported |
| `config.apiBaseURL` | string | `""` | Optional compatible API origin override |
| `config.pollInterval` | duration | `1m` | Poll interval |
| `config.timeout` | duration | `10s` | Per-request timeout |
| `config.workerMetricsEnabled` | boolean | `true` | Enable worker metrics with a token |
| `config.maxWorkers` | integer | `100` | Maximum accepted workers per snapshot |
| `config.rewardsEnabled` | boolean | `true` | Enable reward summaries |
| `config.payoutsEnabled` | boolean | `true` | Enable payout summaries |
| `config.historyDays` | integer | `7` | History window from 1 through 90 days |
| `config.logLevel` | string | `info` | `debug`, `info`, `warn`, or `error` |
| `config.logFormat` | string | `json` | `text` or `json` |
| `config.telemetryPath` | string | `/metrics` | Prometheus metrics path |
| `existingSecret.name` | string | `""` | Existing token Secret name |
| `existingSecret.key` | string | `token` | Key containing the token |
| `existingSecret.mountPath` | string | `/var/run/secrets/braiins-pool-exporter` | Token Secret mount directory |
| `service.type` | string | `ClusterIP` | Kubernetes Service type |
| `service.port` | integer | `9108` | Service port |
| `service.annotations` | object | `{}` | Service annotations |
| `service.labels` | object | `{}` | Additional Service labels; generated selector labels are reserved |
| `resources` | object | requests and limits | CPU and memory resources |
| `livenessProbe` | object | enabled | `/-/healthy` probe configuration |
| `readinessProbe` | object | enabled | `/-/ready` probe configuration |
| `startupProbe` | object | enabled | Startup health probe configuration |
| `revisionHistoryLimit` | integer | `3` | Retained Deployment revisions |
| `strategy` | object | `RollingUpdate` | Deployment strategy |
| `terminationGracePeriodSeconds` | integer | `30` | Pod shutdown grace period |
| `priorityClassName` | string | `""` | Pod PriorityClass name |
| `runtimeClassName` | string | `""` | Pod RuntimeClass name |
| `dnsPolicy` | string | `ClusterFirst` | Pod DNS policy |
| `dnsConfig` | object | `{}` | Additional Pod DNS configuration |
| `nodeSelector` | object | `{}` | Pod node selector |
| `tolerations` | list | `[]` | Pod tolerations |
| `affinity` | object | `{}` | Pod affinity rules |
| `topologySpreadConstraints` | list | `[]` | Pod topology spread constraints |
| `extraArgs` | list | `[]` | Additional exporter arguments |
| `extraEnv` | list | `[]` | Additional environment variables |
| `extraEnvFrom` | list | `[]` | Additional environment sources |
| `extraVolumes` | list | `[]` | Additional Pod volumes |
| `extraVolumeMounts` | list | `[]` | Additional exporter volume mounts |
| `extraContainers` | list | `[]` | Additional sidecar containers |
| `initContainers` | list | `[]` | Additional init containers |
| `podDisruptionBudget.enabled` | boolean | `false` | Create a PodDisruptionBudget |
| `podDisruptionBudget.minAvailable` | integer/string/null | `1` | Minimum available pods |
| `podDisruptionBudget.maxUnavailable` | integer/string/null | `null` | Maximum unavailable pods |
| `networkPolicy.enabled` | boolean | `false` | Create a NetworkPolicy |
| `networkPolicy.ingress.allowExternal` | boolean | `true` | Allow any source to the metrics port |
| `networkPolicy.ingress.from` | list | `[]` | Restricted ingress peers |
| `networkPolicy.additionalIngress` | list | `[]` | Additional ingress rules |
| `networkPolicy.policyTypes` | list | `[Ingress]` | Enforced policy directions |
| `networkPolicy.egress` | list | `[]` | Egress rules when Egress is enforced |
| `serviceMonitor.enabled` | boolean | `false` | Create a ServiceMonitor |
| `serviceMonitor.namespace` | string | `""` | ServiceMonitor namespace; release namespace by default |
| `serviceMonitor.labels` | object | `{}` | Prometheus selector labels |
| `serviceMonitor.annotations` | object | `{}` | ServiceMonitor annotations |
| `serviceMonitor.interval` | duration | `30s` | Scrape interval |
| `serviceMonitor.scrapeTimeout` | duration | `10s` | Scrape timeout |
| `serviceMonitor.path` | string | `/metrics` | Scrape path |
| `serviceMonitor.scheme` | string | `http` | Scrape scheme |
| `serviceMonitor.honorLabels` | boolean | `false` | Honor exporter labels |
| `serviceMonitor.relabelings` | list | `[]` | Target relabeling rules |
| `serviceMonitor.metricRelabelings` | list | `[]` | Metric relabeling rules |
| `serviceMonitor.tlsConfig` | object | `{}` | Optional TLS settings |
