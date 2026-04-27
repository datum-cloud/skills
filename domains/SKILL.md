# Skill: Domains

> **MCP integration:** pending (future phase — will be wired into `agent.datum.net` capability manifest once MCP is ready)

## Description

Manage domain resources in Datum Cloud — attach and verify domains within a project.

## Capabilities

- List and describe domains in a project
- Attach domains to services via YAML manifests
- Apply changes idempotently
- Preview changes before applying
- Delete domains
- Retrieve domain verification tokens (DNS record or HTTP token) from status
- Check permissions before acting

## Key Commands

```bash
datumctl get domains --project <project-id>
datumctl describe domain <name> --project <project-id>
datumctl apply -f domain.yaml --project <project-id>
datumctl diff -f domain.yaml --project <project-id>
datumctl delete domain <name> --project <project-id>
datumctl auth can-i create domains --project <project-id>  # kubectl users only
```

## API Reference

- **API group:** `networking.datumapis.com`
- **Version:** `v1alpha`
- **Kind:** `Domain` (plural: `domains`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`); domains are project-scoped only (`--all-namespaces` is not supported)

## Examples

List all domains in a project:

```bash
datumctl get domains --project my-project
```

Attach a domain:

```yaml
apiVersion: networking.datumapis.com/v1alpha
kind: Domain
metadata:
  name: example-domain
  namespace: default
spec:
  domainName: example.com
```

```bash
datumctl diff -f domain.yaml --project my-project
datumctl apply -f domain.yaml --project my-project
```

Retrieve verification challenge after creation:

```bash
datumctl describe domain example-domain --project my-project
```

Check `status.verification.dnsRecord` or `status.verification.httpToken` in the output for the challenge value to complete domain verification.

## Constraints & Guardrails

- Always use `datumctl` — never `kubectl`
- `--project` is required for all operations; domains are project-scoped only (`--all-namespaces` is not supported)
- Run `datumctl auth can-i create domains --project <project-id>` before attempting creates (kubectl users only)
- Run `datumctl diff -f` before `apply` for any changes
- `--dry-run=server` validates manifest against the API before committing
- `delete` has no confirmation prompt — verify the resource name first
- After creation, check `status.verification.dnsRecord` or `status.verification.httpToken` for the verification challenge: `datumctl describe domain <name> --project <project-id>`
- `networking.datumapis.com/v1alpha` is unstable; field names may change between releases
- **Not currently supported:** TLS provisioning configuration and domain ownership transfer are not available via `datumctl` at this time

## See Also

- [Datum Cloud Domains documentation](https://www.datum.net/docs/domain-dns/domains)
