# AvalonHome Prometheus Exporter Helm Chart

This chart deploys
[avalonhome-prometheus-exporter](https://github.com/brav0charlie/avalonhome-prometheus-exporter),
a lightweight Prometheus exporter for Avalon Home-series ASIC miners such as
Avalon Nano 3S and Avalon Mini 3.

The chart packages upstream app version `0.3.2` and defaults to the same image
tag used by upstream Docker Compose:
`ghcr.io/brav0charlie/avalonhome-prometheus-exporter:v0.3.2`.

## Prerequisites

- Helm 3
- Kubernetes 1.25 or later
- Network access from the exporter Pod to the miner CGMiner TCP API
- Prometheus Operator CRDs only when `serviceMonitor.enabled=true`

The exporter does not require credentials or Kubernetes API access. This chart
does not create Secrets, Roles, RoleBindings, ClusterRoles, or ClusterRoleBindings.

## Install from the local chart

```console
helm install avalonhome-prometheus-exporter \
  ./charts/avalonhome-prometheus-exporter \
  --namespace mining \
  --create-namespace
```

No chart release has been published yet. After version `0.1.0` is published,
the OCI installation command will be:

```console
helm install avalonhome-prometheus-exporter \
  oci://ghcr.io/nicosmuts/charts/avalonhome-prometheus-exporter \
  --version 0.1.0 \
  --namespace mining \
  --create-namespace
```

## Configure miners

Configure one miner with `config.avalonIP`:

```yaml
config:
  avalonIP: "192.168.1.50"
  avalonIPs: []
```

Configure multiple miners with `config.avalonIPs`, which renders the upstream
`AVALON_IPS` environment variable as a comma-separated list:

```yaml
config:
  avalonIP: ""
  avalonIPs:
    - nano3s-01.local
    - mini3-rack1.lan
    - 192.168.1.99
```

Only one of `config.avalonIP` or `config.avalonIPs` may be set. The default
miner API port is `4028`.

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

The default endpoint is the Service port named `http` at `/metrics`. The
exporter health endpoint is `/health` and is used for liveness and readiness
probes.

## Pin the image by digest

A digest takes precedence over the tag:

```yaml
image:
  digest: sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef
```

Set the digest to the OCI image index or manifest digest you have approved for
your environment.

## Application configuration

The chart maps supported settings to upstream environment variables:

```yaml
config:
  avalonPort: 4028
  updateInterval: 15
  exporterPort: 9100
  exportChipMetrics: false
  minerTimeout: 5.0
  enableDebugEndpoint: false
  logLevel: INFO
```

`EXPORT_CHIP_METRICS=true` enables per-chip telemetry and can increase metric
cardinality. The debug endpoint is disabled by default because it exposes
internal state, including miner addresses and recent errors.

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
`networkPolicy.policyTypes`, supply DNS and miner API egress rules appropriate
to the cluster and miner network.

## Upgrade and uninstall

Review upstream and chart release notes, then upgrade with an explicit chart
version:

```console
helm upgrade avalonhome-prometheus-exporter \
  oci://ghcr.io/nicosmuts/charts/avalonhome-prometheus-exporter \
  --version <new-chart-version> \
  --namespace mining \
  --reuse-values
```

Prefer a checked values file over `--reuse-values` when defaults or schemas
change. To uninstall:

```console
helm uninstall avalonhome-prometheus-exporter --namespace mining
```

## Security

Defaults enforce non-root execution, RuntimeDefault seccomp, no privilege
escalation, all capabilities dropped, a read-only root filesystem, and no
service-account token mount. The chart creates no RBAC resources and does not
use host networking, host PID, host IPC, or privileged containers.

Miner hostnames and IP addresses are emitted as labels and may expose internal
network details. Keep the exporter Service private and use NetworkPolicy where
appropriate.

No credentials, wallet data, generated packages, or private configuration are
bundled in this chart.

## Versioning

Chart `version` tracks Kubernetes packaging changes and follows Semantic
Versioning. `appVersion` tracks the packaged upstream exporter version. They
change independently.

## Values

| Key | Type | Default | Description |
| --- | --- | --- | --- |
| `replicaCount` | integer | `1` | Deployment replicas |
| `image.repository` | string | `ghcr.io/brav0charlie/avalonhome-prometheus-exporter` | Exporter image repository |
| `image.tag` | string | `v0.3.2` | Immutable release tag used when no digest is set |
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
| `config.avalonIP` | string | `192.168.1.50` | Single miner hostname or IP rendered as `AVALON_IP` |
| `config.avalonIPs` | list | `[]` | Multiple miners rendered as comma-separated `AVALON_IPS` |
| `config.avalonPort` | integer | `4028` | Miner CGMiner TCP API port |
| `config.updateInterval` | number | `15` | Polling frequency in seconds |
| `config.exporterPort` | integer | `9100` | Exporter HTTP listen port inside the container |
| `config.exportChipMetrics` | boolean | `false` | Enable high-cardinality per-chip metrics |
| `config.minerTimeout` | number | `5.0` | Miner TCP connection timeout in seconds |
| `config.enableDebugEndpoint` | boolean | `false` | Enable the `/debug` endpoint |
| `config.logLevel` | string | `INFO` | `DEBUG`, `INFO`, `WARNING`, `ERROR`, or `CRITICAL` |
| `service.type` | string | `ClusterIP` | Kubernetes Service type |
| `service.port` | integer | `9100` | Service port |
| `service.annotations` | object | `{}` | Service annotations |
| `service.labels` | object | `{}` | Additional Service labels; generated selector labels are reserved |
| `resources` | object | requests and limits | CPU and memory resources |
| `livenessProbe` | object | enabled | `/health` probe configuration |
| `readinessProbe` | object | enabled | `/health` probe configuration |
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
