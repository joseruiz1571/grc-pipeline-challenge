# Week 5: Turn On the Cameras

The starter for this week was written for AWS (CloudTrail + Security Hub). This repo has been GCP-only since Week 1, so Week 5 implements the GCP equivalent the starter itself points to: Data Access audit logs, org policy constraints, and Security Command Center in place of Security Hub.

## What's here

1. **Data Access audit logging** (Terraform, `main.tf`) — `google_project_iam_audit_config` for `storage.googleapis.com` (`DATA_READ`, `DATA_WRITE`) and `iam.googleapis.com` (`DATA_READ`). Maps to AU-2, AU-12, AU-10. Scoped to two named services, not `allServices`, so the config reads as a deliberate decision rather than a blanket enable.
2. **Org policy constraints** (Terraform, `main.tf`) — `iam.disableServiceAccountKeyCreation` and `storage.publicAccessPrevention`, both enforced at the project. Maps to CM-6. This is a configuration guardrail, not an action-deny — the AWS SCP analog on GCP is IAM Deny Policies, which is out of scope here.
3. **Security Command Center Standard** — org-level, not Terraform-managed (see below). Maps to RA-5, SI-4.
4. **SCC entitlement drift gate** (`check-scc-entitlement.sh`) — asserts that the scanners you think you activated are actually entitled and effectively ENABLED. Born from this week's second wrinkle (below); a failed run is itself signed evidence.

## The GCP wrinkle worth reading

`gcloud-grc-pipeline` started as an **orgless project** (`parent: null`). Two GCP controls fundamentally require an organization-attached project and there is no way around it:

- **Org policy** — the predefined `roles/orgpolicy.policyAdmin` role cannot be bound at the project level ("not supported for this resource"), and every `orgpolicy.*` permission is blocked from custom roles entirely. Confirmed by direct attempt, not documentation-reading.
- **Security Command Center** — `gcloud scc findings list` returns `NOT_FOUND` with no org-attached project; there's no SCC instance to query.

Fix: moved the project into `joseruiz1571-org` (`gcloud beta projects move gcloud-grc-pipeline --organization=<id>`) after confirming the org had zero pre-existing org policies to inherit unexpectedly. After the move, org policy applied cleanly. This is itself a legitimate finding: **the AWS challenge assumes a single-account setup where these controls are directly enable-able; the GCP equivalents assume an organization-scoped project as a precondition, which is not obvious from either CSP's marketing.**

Security Command Center's *very first* activation for a brand-new organization is a one-time console click (`https://console.cloud.google.com/security/command-center/setup`) — there is no `gcloud`/Terraform path to bootstrap it, confirmed via `gcloud scc`, `gcloud scc manage services`, and `gcloud alpha scc` all failing on a never-enrolled org even with `roles/securitycenter.admin` granted. Also confirmed: no clean Terraform resource exists for SCC activation itself (`google_scc_source` only manages custom finding sources under an *already-activated* instance — see upstream [hashicorp/terraform-provider-google#14067](https://github.com/hashicorp/terraform-provider-google/issues/14067)).

## The second wrinkle: the tier drifted out from under the plan

The console activation was completed and the Standard-tier subscription went live (`PAY_AS_YOU_GO`, confirmed via the Security Center Management API). Sources registered, findings API answering. Then 40+ hours passed with zero findings — because **Security Health Analytics never ran, and was never going to.**

Google restructured SCC's tiers: per the [service-tiers docs](https://cloud.google.com/security-command-center/docs/service-tiers), SHA is *"not supported with new Standard tier activations"* — only organizations migrated from the Standard-legacy tier keep it. Every tutorial describing "activate Standard, wait ~12h for the first Security Health Analytics scan" documents the legacy tier. On a fresh 2026 activation, SHA's `intendedEnablementState: INHERITED` resolves to `effectiveEnablementState: DISABLED`, and enabling it directly fails: `gcloud scc manage services update security-health-analytics --enablement-state=ENABLED` → `FAILED_PRECONDITION`. Confirmed by direct attempt, not documentation-reading.

The trap generalizes: **sources get registered at activation regardless of entitlement**, so a successful-looking activation with a silent scanner is the default failure mode, not an edge case. `check-scc-entitlement.sh` is the response — a post-activation assertion that every expected service is *effectively* ENABLED, failing fast instead of waiting indefinitely for a scan that will never arrive. Its failing run against this org, plus the raw service-state capture (`evidence/scc-services.json`) and the honest empty findings query (`evidence/scc-findings.json`), are this week's signed evidence bundle — compliance drift, detected and preserved, in a week that was about turning on the cameras.

## Done when

- [x] `terraform apply` succeeds for audit config + org policy — verified, `terraform state list` shows all 4 resources.
- [x] `gcloud logging read` shows a live Data Access log entry for `storage.googleapis.com` after a test read (`gsutil ls`) — `storage.objects.list` entry captured.
- [ ] Data Access log entry for `iam.googleapis.com` — config applied and verified in state; a live DATA_READ-triggering call (`GetIamPolicy` turned out to be `ADMIN_READ`, always-on) wasn't exercised this session. Deferred, not blocking.
- [x] `gcloud resource-manager org-policies describe` confirms both org policy constraints enforced.
- [x] Security Command Center evidence captured — revised from "findings captured" after the tier-drift discovery: SCC Standard is active, but new Standard activations don't entitle Security Health Analytics, so the signed evidence is the entitlement drift itself (`scc-services.json`, `scc-findings.json`, `scc-entitlement-report.txt`) rather than misconfiguration findings.
- [x] Evidence bundle Cosign-signed and verified via `week-4/verify-evidence.sh` — same chain of custody as Week 4, no new signing mechanism. Signed locally (keyless device flow, Google OIDC), so verification needs the issuer override:

  ```bash
  VERIFY_OIDC_ISSUER="https://accounts.google.com" ../week-4/verify-evidence.sh week5-evidence.tar.gz
  # -> CHAIN INTACT
  ```

## No teardown

Unlike the AWS path, none of this is billable in a way that requires same-day teardown — Data Access audit logs and org policy are effectively free at this scale, and Security Command Center Standard tier is free. These are being left in place as permanent security posture, not a one-day experiment. `teardown.sh` remains unused for this week.
