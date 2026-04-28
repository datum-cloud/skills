# Skill: Metrics Export

> **MCP integration:** pending (future phase — will be wired into `agent.datum.net` capability manifest once MCP is ready)

## Description

Configure metrics export pipelines in Datum Cloud — define named sources (with optional MetricsQL filters) and sinks (Prometheus remote write endpoints) to ship project metrics to external observability platforms such as Grafana Cloud.

## Capabilities

- List and describe export policies in a project
- Create metrics export pipelines from YAML manifests
- Filter exported metrics using MetricsQL selector expressions
- Configure Prometheus remote write endpoints with Secret-backed credentials
- Tune batching and retry behavior per sink
- Apply changes idempotently
- Preview changes before applying
- Delete export policies safely

## Key Commands

```bash
datumctl get exportpolicies --project <project-id>
datumctl describe exportpolicy <name> --project <project-id>
datumctl apply -f exportpolicy.yaml --project <project-id>
datumctl diff -f exportpolicy.yaml --project <project-id>
datumctl delete exportpolicy <name> --project <project-id>
datumctl auth can-i create exportpolicies --project <project-id>
```

## API Reference

- **API group:** `telemetry.miloapis.com` ⚠️ **alpha — field names may change**
- **Version:** `v1alpha1`
- **Kind:** `ExportPolicy` (plural: `exportpolicies`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`)

**Key spec fields:**

`spec.sources[]` — one or more named metric source definitions:
- `name` — source name, referenced by sinks (required)
- `metrics.metricsql` — optional MetricsQL selector to filter which metrics are exported (e.g. `{job="myapp"}`)

`spec.sinks[]` — one or more export destinations:
- `name` — sink name (required)
- `sources[]` — list of source names to include in this sink (required)
- `target.prometheusRemoteWrite` — Prometheus remote write configuration (required):
  - `endpoint` — remote write URL (required); e.g. Grafana Cloud remote write endpoint
  - `authentication.basicAuth.secretRef.name` — name of a Kubernetes Secret in the same namespace containing credentials (required for authenticated endpoints)
  - `batch.maxSize` — maximum number of samples per batch (required)
  - `batch.timeout` — maximum time to wait before flushing a batch (required); e.g. `"5s"`
  - `retry.maxAttempts` — maximum number of retry attempts on failure (required)
  - `retry.backoffDuration` — wait time between retries (required); e.g. `"1s"`

**Status fields:**
- `status.conditions` — top-level conditions (`Accepted`, `Programmed`)
- `status.sinks[].name` — per-sink status
- `status.sinks[].conditions` — per-sink conditions

## Examples

### Export all project metrics to Grafana Cloud

First, create a Secret with your Grafana Cloud credentials (username = Grafana Cloud instance ID, password = API token):

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: grafana-cloud-credentials
  namespace: default
stringData:
  username: "123456"
  password: "glc_eyJ..."
```

```bash
datumctl apply -f grafana-secret.yaml --project my-project
```

Create the export policy:

```yaml
apiVersion: telemetry.miloapis.com/v1alpha1
kind: ExportPolicy
metadata:
  name: grafana-cloud-export
  namespace: default
spec:
  sources:
    - name: all-metrics
  sinks:
    - name: grafana-cloud
      sources:
        - all-metrics
      target:
        prometheusRemoteWrite:
          endpoint: https://prometheus-prod-01-prod-us-east-0.grafana.net/api/prom/push
          authentication:
            basicAuth:
              secretRef:
                name: grafana-cloud-credentials
          batch:
            maxSize: 500
            timeout: "5s"
          retry:
            maxAttempts: 3
            backoffDuration: "1s"
```

```bash
datumctl diff -f exportpolicy.yaml --project my-project
datumctl apply -f exportpolicy.yaml --project my-project
datumctl describe exportpolicy grafana-cloud-export --project my-project
# Look for status.conditions: Programmed=True
```

### Export filtered metrics (specific job or label set)

Use a MetricsQL selector on the source to limit which metrics are shipped:

```yaml
apiVersion: telemetry.miloapis.com/v1alpha1
kind: ExportPolicy
metadata:
  name: app-metrics-export
  namespace: default
spec:
  sources:
    - name: app-only
      metrics:
        metricsql: '{job="my-app"}'
  sinks:
    - name: grafana-cloud
      sources:
        - app-only
      target:
        prometheusRemoteWrite:
          endpoint: https://prometheus-prod-01-prod-us-east-0.grafana.net/api/prom/push
          authentication:
            basicAuth:
              secretRef:
                name: grafana-cloud-credentials
          batch:
            maxSize: 500
            timeout: "5s"
          retry:
            maxAttempts: 3
            backoffDuration: "1s"
```

```bash
datumctl diff -f app-metrics-export.yaml --project my-project
datumctl apply -f app-metrics-export.yaml --project my-project
```

## Constraints & Guardrails

- Always use `datumctl` — never `kubectl`
- `--project` is required for all operations
- `telemetry.miloapis.com/v1alpha1` is unstable; field names may change between releases
- Credentials must be stored in a Kubernetes Secret in the same namespace — do not inline passwords in the ExportPolicy manifest
- `spec.sinks[].sources[]` must reference names defined in `spec.sources[]` in the same manifest
- `batch.maxSize`, `batch.timeout`, `retry.maxAttempts`, and `retry.backoffDuration` are all required fields on every sink — omitting any will fail validation
- Run `datumctl auth can-i create exportpolicies --project <project-id>` before attempting creates (kubectl users only)
- Run `datumctl diff -f` before `apply` for any changes
- `--dry-run=server` validates the manifest against the API before committing
- `delete` has no confirmation prompt — always verify the resource name first
- Check `status.sinks[].conditions` per sink — a policy-level `Programmed=True` does not guarantee each individual sink is healthy

## See Also

- [Datum Cloud Metrics Export documentation](https://www.datum.net/docs/observability/metrics-export)
- [Grafana Cloud remote write endpoint](https://grafana.com/docs/grafana-cloud/send-data/metrics/metrics-prometheus/prometheus-config-examples/remote-write-examples/)
- [MetricsQL documentation](https://docs.victoriametrics.com/metricsql/)
