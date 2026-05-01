# Skill: DNS Zones & Records

> **MCP integration:** pending (future phase — will be wired into `agents.datum.net` capability manifest once MCP is ready)

## Description

Manage DNS zones and record sets in Datum Cloud — create, inspect, update, and delete `DNSZone` and `DNSRecordSet` resources within a project.

## Capabilities

- List and describe DNS zones in a project
- Create DNS zones from YAML manifests
- Manage DNS record sets (A, AAAA, CNAME, MX, TXT, ALIAS, CAA, SRV, and more)
- Set and update TTL per record entry
- Apply changes idempotently
- Preview changes before applying
- Delete DNS zones and record sets safely
- Validate DNS propagation via status conditions and external dig queries
- Check permissions before acting

## Key Commands

**Zones:**
```bash
datumctl get dnszones --project <project-id>
datumctl describe dnszone <name> --project <project-id>
datumctl apply -f dnszone.yaml --project <project-id>
datumctl diff -f dnszone.yaml --project <project-id>
datumctl delete dnszone <name> --project <project-id>
datumctl auth can-i create dnszones --project <project-id>  # kubectl users only
datumctl get dnszoneclasses --project <project-id>
```

**Record Sets:**
```bash
datumctl get dnsrecordsets --project <project-id>
datumctl describe dnsrecordset <name> --project <project-id>
datumctl apply -f dnsrecordset.yaml --project <project-id>
datumctl diff -f dnsrecordset.yaml --project <project-id>
datumctl delete dnsrecordset <name> --project <project-id>
datumctl auth can-i create dnsrecordsets --project <project-id>  # kubectl users only
```

## API Reference

**DNSZone**
- **API group:** `dns.networking.miloapis.com`
- **Version:** `v1alpha1`
- **Kind:** `DNSZone` (plural: `dnszones`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`) or org-wide (`--organization --all-namespaces`)

**DNSRecordSet**
- **API group:** `dns.networking.miloapis.com`
- **Version:** `v1alpha1`
- **Kind:** `DNSRecordSet` (plural: `dnsrecordsets`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`)
- **Key spec fields:**
  - `spec.dnsZoneRef.name` — name of the parent `DNSZone` (required)
  - `spec.recordType` — record type: `A`, `AAAA`, `ALIAS`, `CNAME`, `MX`, `TXT`, `CAA`, `SRV`, `NS`, `HTTPS`, `SVCB`, `TLSA`
  - `spec.records[]` — one or more record entries; each entry has:
    - `name` — owner name relative to the zone (required)
    - `ttl` — optional TTL override in seconds
    - `<recordType>`.`content` — type-specific value field (e.g. `a.content`, `cname.content`, `txt.content`)
- **Status fields:**
  - `status.conditions` — includes `Accepted` and `Programmed` readiness conditions

## Examples

List all DNS zones in a project:

```bash
datumctl get dnszones --project my-project
```

Create a DNS zone:

```yaml
apiVersion: dns.networking.miloapis.com/v1alpha1
kind: DNSZone
metadata:
  name: example-zone
  namespace: default
spec:
  domainName: example.com
  dnsZoneClassName: datum-external-global-dns
```

```bash
datumctl diff -f dnszone.yaml --project my-project
datumctl apply -f dnszone.yaml --project my-project
```

Check available zone classes before creating:

```bash
datumctl get dnszoneclasses --project my-project
```

Create an A record:

```yaml
apiVersion: dns.networking.miloapis.com/v1alpha1
kind: DNSRecordSet
metadata:
  name: www-a
  namespace: default
spec:
  dnsZoneRef:
    name: example-zone
  recordType: A
  records:
    - name: www
      ttl: 300
      a:
        content: "203.0.113.10"
```

```bash
datumctl diff -f dnsrecordset.yaml --project my-project
datumctl apply -f dnsrecordset.yaml --project my-project
```

Create a TXT record (e.g. SPF):

```yaml
apiVersion: dns.networking.miloapis.com/v1alpha1
kind: DNSRecordSet
metadata:
  name: spf
  namespace: default
spec:
  dnsZoneRef:
    name: example-zone
  recordType: TXT
  records:
    - name: "@"
      ttl: 3600
      txt:
        content: "v=spf1 include:example.com ~all"
```

Validate propagation — check the `Programmed` condition in status:

```bash
datumctl describe dnsrecordset www-a --project my-project
# Look for status.conditions: Programmed=True
```

Verify propagation externally via Datum's authoritative nameservers:

```bash
dig www.example.com @ns1.datumdomains.net
# Datum authoritative nameservers: ns1–ns4.datumdomains.net
```

## Constraints & Guardrails

- Always use `datumctl` — never `kubectl`
- `--project` is required for all operations unless using `--organization --all-namespaces`
- Run `datumctl auth can-i create dnszones --project <project-id>` before attempting zone creates (kubectl users only)
- Run `datumctl auth can-i create dnsrecordsets --project <project-id>` before attempting record set creates (kubectl users only)
- Run `datumctl get dnszoneclasses --project <project-id>` to find a valid `dnsZoneClassName` before creating a zone
- `spec.dnsZoneRef.name` must match an existing `DNSZone` in the same namespace and project
- Set `spec.recordType` to match exactly one type-specific field in each `records[]` entry (e.g. `recordType: A` requires `a.content`)
- Run `datumctl diff -f` before `apply` for any changes
- `--dry-run=server` validates the manifest against the API before committing
- `delete` has no confirmation prompt — always verify the resource name first
- `dns.networking.miloapis.com/v1alpha1` is unstable; field names may change between releases

## See Also

- [Datum Cloud DNS documentation](https://www.datum.net/docs/domain-dns/dns.md)
