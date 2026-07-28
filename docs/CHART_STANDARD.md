# Chart Standard

This standard applies to charts maintained in this repository. Exceptions must
be documented in the chart README.

## Required structure

Every chart must include:

```text
charts/<chart-name>/
├── Chart.yaml
├── values.yaml
├── values.schema.json
├── README.md
├── ci/
│   └── default-values.yaml
└── templates/
    ├── _helpers.tpl
    ├── deployment.yaml
    ├── service.yaml
    ├── serviceaccount.yaml
    ├── tests/
    └── NOTES.txt
```

Add ConfigMaps, Secrets, ServiceMonitors, dashboards, NetworkPolicies, and
other resources only when the application needs them.

## Metadata and compatibility

- Use Helm 3-compatible chart APIs (`apiVersion: v2`).
- Use lowercase kebab-case chart names.
- Follow Semantic Versioning for chart `version`.
- Set an explicit `appVersion`; it tracks the upstream application and is
  independent of the chart version.
- Declare a tested Kubernetes version range in `kubeVersion`.
- Set `type: application`, source URLs, maintainers, and an SPDX license
  annotation where practical.
- Use repository URLs rooted at <https://github.com/nicosmuts/helm-charts>.

## Values contract

Every chart must provide and document:

- image repository, tag, optional digest, and pull policy;
- pod and container security contexts with secure defaults;
- CPU and memory requests and limits;
- startup, readiness, and liveness probes as appropriate;
- service-account creation, name, labels, and annotations;
- common, pod, and resource labels and annotations;
- node selector, affinity, tolerations, topology spread constraints, and
  priority class;
- extra environment variables and `envFrom` sources;
- extra volumes and mounts where the workload reasonably supports them.

`values.schema.json` must validate user-facing values. The README values table
must be generated from, or checked against, `values.yaml`.

Digest pinning takes precedence over an image tag when both are set. Charts
must not create plaintext credentials by default; prefer references to
existing Secrets. If secret creation is explicitly supported, it must be
opt-in and clearly warn about exposure through Helm release state.

## Kubernetes resources

- Use stable Kubernetes APIs appropriate to the supported range.
- Use standard Kubernetes recommended labels and deterministic names.
- Make selectors immutable and keep selector labels separate from descriptive
  labels.
- Make metrics `ServiceMonitor` support optional when relevant. Add
  `PodMonitor` only when service-based scraping is unsuitable.
- Support optional Grafana dashboard provisioning for applications with a
  maintained dashboard.
- Support NetworkPolicy where useful, with behavior documented.
- Support PodDisruptionBudget for replicated, disruption-sensitive workloads.
- Avoid cluster-scoped resources unless essential and explicitly documented.

## Quality gates

Each chart must pass strict `helm lint`, schema validation, rendering with
default CI values, and packaging. Add Helm test hooks that verify meaningful
service behavior. Test important optional branches with additional files in
`ci/`. Generated manifests must contain no credentials or private environment
configuration.
