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
- Check for DNSSEC before a nameserver cutover, and walk the user through turning it off
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

## DNSSEC and nameserver cutover

Datum DNS does not currently support DNSSEC. Zones are not signed, and `DS`, `DNSKEY`, `RRSIG`, `NSEC`, and `NSEC3` are not valid record types.

If the registrar still publishes a `DS` record when the nameservers move to Datum, validating resolvers return `SERVFAIL` and the domain stops resolving for most users. Check before you tell a user to switch nameservers:

```bash
dig +short DS example.com
# Empty output: DNSSEC is off, safe to cut over
# Any output: DNSSEC is on, stop and follow the steps below
```

If the domain exists as a `Domain` resource, `datumctl describe domain <name> --project <project-id>` also shows `status.registration.dnssec.enabled` and `status.registration.dnssec.ds[]` from the registry.

When DNSSEC is on, walk the user through these steps in order:

1. Remove the `DS` record (or turn off DNSSEC) at the registrar, and at the current DNS provider if it manages DNSSEC. The current provider keeps serving the zone during this step.
2. Wait until `dig +short DS example.com` returns nothing, then one more full `DS` TTL (`dig DS example.com` shows it; 86400s for `.com`/`.net`).
3. Create the zone on Datum and import records.
4. Change the nameservers to `ns1`–`ns4.datumdomains.net`.

Diagnose a domain that broke after cutover: `dig example.com` returns `SERVFAIL` but `dig +cd example.com` returns answers. The fix is to remove the `DS` record at the registrar; resolvers recover as the cached `DS` expires.

A subdomain delegated to Datum from a signed parent zone hosted elsewhere works as long as the parent has no `DS` record for that subdomain.

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
- Datum DNS does not currently support DNSSEC. Never suggest creating `DS`, `DNSKEY`, `RRSIG`, `NSEC`, or `NSEC3` records, and never imply DNSSEC can be enabled
- Before recommending a nameserver change to Datum, check for a `DS` record (see DNSSEC and nameserver cutover). If one exists, the user must remove it and wait out its TTL first
- Zone imports skip `DS`, `DNSKEY`, `RRSIG`, `NSEC`, and `NSEC3` records with a warning. This is expected; tell the user rather than retrying
- `dns.networking.miloapis.com/v1alpha1` is unstable; field names may change between releases

## See Also

- [Datum Cloud DNS documentation](https://www.datum.net/docs/domain-dns/dns.md)
- [DNSSEC on Datum](https://www.datum.net/docs/domain-dns/dns#dnssec)
