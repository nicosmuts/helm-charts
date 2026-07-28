# Publishing

Charts are distributed as immutable OCI artifacts under
`oci://ghcr.io/nicosmuts/charts`.

## Versions and tags

The chart `version` describes the packaging and follows Semantic Versioning.
`appVersion` describes the upstream application. An application upgrade
normally changes both; a template-only fix changes only the chart version.

OCI artifact tags are derived from chart versions. Published versions must
never be replaced. A correction requires a new chart version. Git release tags
will use `chart-<chart-name>-<chart-version>` when tag-triggered automation is
introduced.

## Release process

The guarded `release.yml` workflow is initially manual:

1. Select a chart and version already merged into `main`.
2. The workflow verifies the chart metadata and repository.
3. It authenticates to GHCR with the short-lived `GITHUB_TOKEN`.
4. It checks that the requested version is not already retrievable.
5. It lints, renders, and packages the chart.
6. It pushes to `oci://ghcr.io/nicosmuts/charts` and writes a job summary.

The repository stores no registry password. The workflow needs `contents: read`
and `packages: write`; GHCR package access and Actions permissions must permit
the push.

For local administrative access, use a GitHub token with the minimum package
scope and pass it through standard input:

```console
echo "$GHCR_TOKEN" | helm registry login ghcr.io --username <user> --password-stdin
```

Never save the token in this repository. Rollback means installing a known-good
published version; it does not mean overwriting an OCI tag. Provenance or
keyless signing may be added after a signing policy is selected.
