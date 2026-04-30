# Skill: AI Edge (WAF + Traffic Policies)

> **MCP integration:** pending (future phase — will be wired into `agents.datum.net` capability manifest once MCP is ready)

## Description

Manage AI Edge traffic protection and security policies in Datum Cloud — attach Web Application Firewall (WAF), authentication, authorization, and traffic management policies to gateways and HTTP routes. Policies attach via `targetRefs` to existing `Gateway` and `HTTPRoute` resources, providing defense-in-depth against attacks, rate limiting, and traffic control.

## Capabilities

- Deploy WAF (TrafficProtectionPolicy) with OWASP Core Rule Set enforcement
- Configure WAF detection (Observe) and blocking (Enforce) modes
- Attach authentication and authorization policies (SecurityPolicy) to gateways and routes
- Manage circuit breakers, compression, rate limiting, and fault injection (BackendTrafficPolicy)
- List, inspect, and update policies across a project
- Preview changes before applying
- Delete policies safely
- Check permissions before acting

## Key Commands

**TrafficProtectionPolicy (WAF):**
```bash
datumctl get trafficprotectionpolicies --project <project-id>
datumctl get tpp --project <project-id>
datumctl describe trafficprotectionpolicy <name> --project <project-id>
datumctl apply -f tpp.yaml --project <project-id>
datumctl diff -f tpp.yaml --project <project-id>
datumctl delete trafficprotectionpolicy <name> --project <project-id>
datumctl auth can-i create trafficprotectionpolicies --project <project-id>
```

**SecurityPolicy (Auth/AuthZ):**
```bash
datumctl get securitypolicies --project <project-id>
datumctl get sp --project <project-id>
datumctl describe securitypolicy <name> --project <project-id>
datumctl apply -f securitypolicy.yaml --project <project-id>
datumctl diff -f securitypolicy.yaml --project <project-id>
datumctl delete securitypolicy <name> --project <project-id>
```

**BackendTrafficPolicy (Traffic Management):**
```bash
datumctl get backendtrafficpolicies --project <project-id>
datumctl get btp --project <project-id>
datumctl describe backendtrafficpolicy <name> --project <project-id>
datumctl apply -f btp.yaml --project <project-id>
datumctl diff -f btp.yaml --project <project-id>
datumctl delete backendtrafficpolicy <name> --project <project-id>
```

**Gateway & HTTPRoute (reference):**
```bash
datumctl get gateways --project <project-id>
datumctl get httproutes --project <project-id>
datumctl describe gateway <name> --project <project-id>
datumctl describe httproute <name> --project <project-id>
```

## API Reference

### TrafficProtectionPolicy

- **API group:** `networking.datumapis.com` ⚠️ **alpha — field names may change**
- **Version:** `v1alpha`
- **Kind:** `TrafficProtectionPolicy` (plural: `trafficprotectionpolicies`, short: `tpp`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`)
- **Key spec fields:**
  - `spec.mode` — `Observe` (detection only, logs), `Enforce` (blocks), or `Disabled` (inactive)
  - `spec.ruleSets[]` — one or more rule set configurations:
    - `type` — currently supports `OWASPCoreRuleSet`
    - `owaspCoreRuleSet` — OWASP CRS configuration:
      - `paranoiaLevels` — paranoia level thresholds (1–4; higher = stricter, more false positives)
      - `ruleExclusions` — list of OWASP ModSecurity rule IDs to disable
      - `scoreThresholds` — anomaly score thresholds for inbound and outbound blocking
  - `spec.targetRefs[]` — policy attachment targets (required):
    - `group` — `gateway.networking.k8s.io`
    - `kind` — `Gateway` or `HTTPRoute`
    - `name` — target resource name
    - `sectionName` — optional; listener or section within the target
  - `spec.samplingPercentage` — optional; percentage of traffic to analyze (0–100)
- **Status fields:**
  - `status.conditions` — includes `Accepted` and `Programmed` readiness conditions

### SecurityPolicy

- **API group:** `gateway.envoyproxy.io` ⚠️ **alpha — field names may change**
- **Version:** `v1alpha1`
- **Kind:** `SecurityPolicy` (plural: `securitypolicies`, short: `sp`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`)
- **Key spec fields:**
  - `spec.targetRefs[]` — policy attachment targets (required); same structure as TrafficProtectionPolicy
  - `spec.jwt` — JWT token validation
  - `spec.oidc` — OpenID Connect authentication
  - `spec.apiKeyAuth` — API key authentication
  - `spec.basicAuth` — HTTP Basic authentication
  - `spec.extAuth` — external authentication service
  - `spec.authorization` — fine-grained authorization rules
  - `spec.cors` — CORS policy
- **Status fields:**
  - `status.conditions` — standard conditions

### BackendTrafficPolicy

- **API group:** `gateway.envoyproxy.io` ⚠️ **alpha — field names may change**
- **Version:** `v1alpha1`
- **Kind:** `BackendTrafficPolicy` (plural: `backendtrafficpolicies`, short: `btp`)
- **Namespaced:** yes (default namespace: `default`)
- **Scope:** project-level (`--project`)
- **Key spec fields:**
  - `spec.targetRefs[]` — policy attachment targets (required)
  - `spec.rateLimit` — rate limiting rules
  - `spec.circuitBreaker` — circuit breaker thresholds
  - `spec.retry` — retry policy
  - `spec.faultInjection` — fault injection for chaos testing
  - `spec.healthCheck` — backend health check probes
  - `spec.loadBalancer` — load balancing strategy
  - `spec.compression` — response compression
  - `spec.http2` — HTTP/2 settings
- **Status fields:**
  - `status.conditions` — standard conditions

### Gateway (upstream Kubernetes Gateway API)

- **API group:** `gateway.networking.k8s.io`
- **Version:** `v1`
- **Kind:** `Gateway` (plural: `gateways`, short: `gtw`)
- **Reference:** All three policy types attach to gateways via `targetRefs`

### HTTPRoute (upstream Kubernetes Gateway API)

- **API group:** `gateway.networking.k8s.io`
- **Version:** `v1`
- **Kind:** `HTTPRoute`
- **Reference:** Policies can attach to individual routes for fine-grained control

## Examples

List existing gateways before attaching any policy:

```bash
datumctl get gateways --project my-project
datumctl get httproutes --project my-project
```

### Deploy WAF in Observe mode (safe first step)

Start with Observe mode to detect threats without blocking traffic:

```yaml
apiVersion: networking.datumapis.com/v1alpha
kind: TrafficProtectionPolicy
metadata:
  name: waf-observe
  namespace: default
spec:
  mode: Observe
  samplingPercentage: 100
  ruleSets:
    - type: OWASPCoreRuleSet
      owaspCoreRuleSet:
        paranoiaLevels:
          inbound: 2
          outbound: 2
        scoreThresholds:
          inbound: 8
          outbound: 4
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: my-gateway
```

```bash
datumctl diff -f waf-observe.yaml --project my-project
datumctl apply -f waf-observe.yaml --project my-project
datumctl describe trafficprotectionpolicy waf-observe --project my-project
# Look for status.conditions: Programmed=True
```

Tune `ruleExclusions` to suppress false positives, then switch `mode: Enforce` when confident.

### Attach JWT authentication to an HTTPRoute

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: jwt-auth
  namespace: default
spec:
  jwt:
    providers:
      - name: my-provider
        issuer: https://auth.example.com/
        audiences:
          - my-api
        remoteJWKS:
          uri: https://auth.example.com/.well-known/jwks.json
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: HTTPRoute
      name: api-route
```

```bash
datumctl diff -f jwt-auth.yaml --project my-project
datumctl apply -f jwt-auth.yaml --project my-project
```

### Add rate limiting and circuit breaker

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: traffic-control
  namespace: default
spec:
  rateLimit:
    - action: Deny
      limit:
        requests: 100
        unit: Hour
      clientSelectors:
        - headers:
            - name: x-user-id
  circuitBreaker:
    maxConnections: 500
    maxPendingRequests: 100
    maxRequests: 1000
    maxRetries: 3
  targetRefs:
    - group: gateway.networking.k8s.io
      kind: Gateway
      name: my-gateway
```

```bash
datumctl diff -f traffic-control.yaml --project my-project
datumctl apply -f traffic-control.yaml --project my-project
```

## Constraints & Guardrails

- Always use `datumctl` — never `kubectl`
- `--project` is required for all operations
- `networking.datumapis.com/v1alpha` and `gateway.envoyproxy.io/v1alpha1` are unstable; field names may change between releases
- All three policy types require existing `Gateway` or `HTTPRoute` resources in the same namespace and project via `targetRefs` — policies cannot stand alone
- Use `sectionName` in `targetRefs` to scope a policy to a specific listener or route rule
- Run `datumctl auth can-i create trafficprotectionpolicies --project <project-id>` before attempting creates (kubectl users only)
- Run `datumctl diff -f` before `apply` for any changes
- `--dry-run=server` validates the manifest against the API before committing
- `delete` has no confirmation prompt — always verify the resource name first
- Start WAF with `mode: Observe` and tune `ruleExclusions` before switching to `mode: Enforce`
- Increasing `paranoiaLevels` beyond 2 significantly increases false positive rate — test thoroughly

## See Also

- [Datum Cloud AI Edge documentation](https://www.datum.net/docs/ai-edge/overview.md)
- [Envoy Gateway SecurityPolicy](https://gateway.envoyproxy.io/docs/api/extension_types/#securitypolicy)
- [OWASP Core Rule Set](https://coreruleset.org/)
