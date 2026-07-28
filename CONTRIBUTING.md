# Contributing

Thank you for improving these charts.

## Before opening a change

- Use an issue to discuss a new chart or substantial behavior change.
- Keep charts generic; do not include private domains, credentials, cluster
  addresses, or environment-specific scheduling.
- Follow [the chart standard](docs/CHART_STANDARD.md).
- Make chart and application version changes intentionally.
- Add or update tests, schema, example values, and documentation.

## Development workflow

1. Fork the repository and create a focused branch.
2. Add or change one chart at a time where practical.
3. Run `./scripts/helm-charts.ps1 verify` (or `make verify`).
4. Update the chart changelog or release notes when that convention is added.
5. Open a pull request using the supplied template.

Commits should be clear and scoped. Pull requests must pass CI and resolve
review conversations before merging.

By contributing, you agree that your contribution is licensed under this
repository's MIT License unless a chart clearly states otherwise.
