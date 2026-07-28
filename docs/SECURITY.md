# Chart Security

## Secrets

Charts must not contain real credentials or create plaintext credentials by
default. Prefer a value naming an existing Kubernetes Secret and specific key
references. Secret creation, if unavoidable, must be explicit, opt-in, and
document the exposure of values in Helm release state.

## Runtime controls

Use least-privilege pod and container security contexts. Workloads should run
as non-root, disallow privilege escalation, drop capabilities, and use a
read-only root filesystem when the application supports it. Document any
exception. Expose resource controls, probes, service-account settings, and
NetworkPolicy where relevant.

## Supply chain

- Use specific image tags and support immutable image digests.
- Document image sources and supported architectures.
- Prefer upstream images with published provenance and vulnerability handling.
- Pin GitHub Actions to maintained major versions and review automated updates.
- Treat chart versions as immutable after publication.
- Do not commit packaged charts, registry credentials, kubeconfigs, or
  generated `index.yaml` files.

Report suspected vulnerabilities using the process in
[the repository security policy](../SECURITY.md).
