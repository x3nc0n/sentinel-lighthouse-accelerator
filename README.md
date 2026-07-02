# Microsoft Sentinel — Multi-Tenant Lighthouse Accelerator

Delegate **one resource group** (your Microsoft Sentinel RG) to a service provider / MSSP tenant using
[Azure Lighthouse](https://learn.microsoft.com/azure/lighthouse/), with a **three-tier operator model**
and **just-in-time (PIM) elevation** for Tier 3 — deployable with a single click.

This is a focused accelerator: it does one thing well. Unlike the general
[Azure Lighthouse samples](https://github.com/Azure/Azure-Lighthouse-samples), you **don't** have to
hand-craft a big `authorizations` JSON array. You just provide **three group object IDs** and go.

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#blade/Microsoft_Azure_CreateUIDef/CustomDeploymentBlade/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fx3nc0n%2Fsentinel-lighthouse-accelerator%2Fmain%2Fazuredeploy.json/createUIDefinitionUri/https%3A%2F%2Fraw.githubusercontent.com%2Fx3nc0n%2Fsentinel-lighthouse-accelerator%2Fmain%2FcreateUiDefinition.json)
[![Visualize](https://raw.githubusercontent.com/Azure/azure-quickstart-templates/master/1-CONTRIBUTION-GUIDE/images/visualizebutton.svg?sanitize=true)](http://armviz.io/#/?load=https%3A%2F%2Fraw.githubusercontent.com%2Fx3nc0n%2Fsentinel-lighthouse-accelerator%2Fmain%2Fazuredeploy.json)

> The **Deploy to Azure** button above opens a guided form (subscription + resource group pickers,
> three group-ID fields, PIM options). Prefer the raw template with no form? Use
> [this link](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fx3nc0n%2Fsentinel-lighthouse-accelerator%2Fmain%2Fazuredeploy.json).

---

## What it grants

| Tier | Standing access (always on) | Just-in-time (PIM) |
|------|-----------------------------|--------------------|
| **Tier 1** | Sentinel Responder · Sentinel Playbook Operator · Reader | — |
| **Tier 2** | Sentinel Responder · Sentinel Playbook Operator · Reader | — |
| **Tier 3** | Sentinel Responder · Sentinel Playbook Operator · Reader | **Sentinel Contributor** · **Logic App Contributor** (time-bound, MFA) |

All three tiers share the same **standing** roles. Only **Tier 3** can elevate on demand to the two
broader roles, which expire automatically after the configured duration (default 8 hours, MFA required).
Tier 3 also holds a delete-only **offboarding safeguard** role — see [Ending the delegation](#ending-the-delegation-offboarding).

### Built-in roles used

| Role | GUID | Where |
|------|------|-------|
| Microsoft Sentinel Responder | `3e150937-b8fe-4cfb-8069-0eaf05ecd056` | Standing (all tiers) |
| Microsoft Sentinel Playbook Operator | `51d6186e-6489-4900-b93f-92e23144cca5` | Standing (all tiers) |
| Reader | `acdd72a7-3385-48ef-bd42-f606fba81ae7` | Standing (all tiers) |
| Microsoft Sentinel Contributor | `ab8e14d6-4a74-4a29-9ba8-549422addade` | Eligible / PIM (Tier 3) |
| Logic App Contributor | `87a39d53-fc1b-424a-814c-f7e04687dc9e` | Eligible / PIM (Tier 3) |
| Managed Services Registration assignment Delete Role | `91c1777a-f3dc-4fae-b103-61d183457e46` | Standing (Tier 3) — offboarding safeguard, no data access |

Every standing role is free of `Microsoft.Authorization/*/write`, which is required for standing
Lighthouse delegation. Broader access is delivered through the **eligible (PIM)** path instead.

### Alignment with Microsoft's recommended role assignments

The tier model is a direct implementation of Microsoft's
[recommended role assignments for Microsoft Sentinel users](https://learn.microsoft.com/en-us/azure/sentinel/roles#recommended-role-assignments-for-microsoft-sentinel-users)
— analysts get standing access, engineers get elevated access (here, just-in-time):

| Microsoft-recommended user type | Recommended roles (at the Sentinel RG) | This accelerator |
|---------------------------------|----------------------------------------|------------------|
| **Security analysts** | Microsoft Sentinel Responder · Microsoft Sentinel Playbook Operator | **Tier 1 & Tier 2** — standing (plus Reader for resource visibility) |
| **Security engineers** | Microsoft Sentinel Contributor · Logic App Contributor | **Tier 3** — **just-in-time (PIM)**: the same broader access, but time-bound and MFA-gated instead of standing |
| **Service principal** | Microsoft Sentinel Contributor | Out of scope — grant separately to any automation service principal |

> Microsoft recommends assigning these roles at the **resource group** that contains the Sentinel
> workspace, so Logic Apps and playbooks in the same RG are covered by one set of assignments. This
> accelerator delegates exactly that scope.

---

## Who deploys this, and where

> **Direction matters — this is the #1 Lighthouse mistake.**
> The template is deployed by an admin of the **customer** tenant (the tenant that *owns* the Sentinel
> resource group), and it grants access to the **provider** (MSSP) tenant.
> The `managedByTenantId` parameter is the **provider** tenant — *not* your own.

| You are… | You provide… |
|----------|--------------|
| The **customer** (owns the Sentinel RG) | Deploy this template into your Sentinel resource group. |
| The **provider** / MSSP | Give the customer your **tenant ID** and the **object IDs** of your three tier groups. |

### Prerequisites

- **Deployer** (customer admin) needs **Owner** on the target resource group (to write
  `Microsoft.ManagedServices/registrationDefinitions` and `registrationAssignments`).
- The three provider groups must be **security groups** (not Microsoft 365 groups) in the provider tenant.
- The provider tenant ID and the three group object IDs.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|:--------:|---------|-------------|
| `managedByTenantId` | ✅ | — | Provider (MSSP) tenant GUID. |
| `rgName` | ✅ | — | Name of the existing Sentinel resource group to delegate. |
| `tier1GroupId` / `tier2GroupId` / `tier3GroupId` | ✅ | — | Object IDs of the three provider security groups. |
| `tier1GroupName` / `tier2GroupName` / `tier3GroupName` | | `MSSP Tier N Operators` | Friendly names shown in the portal. |
| `mspOfferName` | | `Microsoft Sentinel Multi-Tenant Accelerator` | Offer name in the *Service providers* blade. |
| `mspOfferDescription` | | *(see template)* | Offer description. |
| `standingRoleDefinitionIds` | | Responder, Playbook Operator, Reader | Standing roles for **all** tiers. Override to customize. |
| `tier3EligibleRoleDefinitionIds` | | Sentinel Contributor, Logic App Contributor | Tier 3 PIM roles. |
| `pimMaxActivationDuration` | | `PT8H` | ISO-8601 max activation time for Tier 3. |
| `pimRequireMfa` | | `true` | Require Azure MFA for Tier 3 activation. |
| `includeDeleteRole` | | `true` | Grant Tier 3 the *Managed Services Registration assignment Delete Role* so the provider can offboard the delegation itself. No data access. Set `false` to omit. |

---

## Ending the delegation (offboarding)

Either side can remove the delegation at any time:

- **Customer** — in the Azure portal: **Service providers → Service provider offers → Delegations**,
  select the offer, and delete it. Or via CLI:
  ```bash
  az managedservices assignment delete --assignment <assignmentId> --scope /subscriptions/<subId>/resourceGroups/<rgName>
  ```
- **Provider** (when `includeDeleteRole` is `true`) — Tier 3 operators hold the built-in
  **Managed Services Registration assignment Delete Role**, so they can delete the
  `registrationAssignment` from the customer scope even if the customer never offboards it. This is a
  break-glass for MSSP relationships that end without the customer completing offboarding. The role
  grants **no** access to customer data or resources — only the ability to remove the delegation.

> Deleting the **assignment** revokes all delegated access to the resource group. The
> **registration definition** (the offer) can remain for reuse, or be deleted separately.

---

## Deploy from the CLI

Run as a **customer-tenant admin**, signed in to the tenant that owns the Sentinel RG.
This is a **subscription-scoped** deployment (`az deployment sub create`); only the resource group
named in `rgName` is delegated.

### Bicep

```bash
az deployment sub create \
  --location eastus \
  --template-file main.bicep \
  --parameters \
      rgName=<your-sentinel-rg> \
      managedByTenantId=<provider-tenant-guid> \
      tier1GroupId=<tier1-group-object-id> \
      tier2GroupId=<tier2-group-object-id> \
      tier3GroupId=<tier3-group-object-id>
```

### ARM / JSON

```bash
az deployment sub create \
  --location eastus \
  --template-file azuredeploy.json \
  --parameters azuredeploy.parameters.json
```

> `--location` only sets the deployment metadata region — Lighthouse resources are not placed there.
> Edit `azuredeploy.parameters.json` first — replace the placeholder GUIDs and `rgName` with the
> provider tenant ID, your three group object IDs, and your Sentinel resource group name.

---

## Verify the delegation

```bash
# From the customer tenant — list registration assignments on the resource group
az rest --method GET \
  --url "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/<your-sentinel-rg>/providers/Microsoft.ManagedServices/registrationAssignments?api-version=2022-10-01&\$expand=registrationDefinition"
```

Or in the portal: open the resource group → **Access control (IAM)** → or search **Service providers**.
Provider-side operators will see the delegated RG under **My customers** in the Azure portal, and can
activate their Tier 3 eligible roles from **Azure Lighthouse → My customers → (RG) → activate**.

---

## Remove the delegation

```bash
# Get the assignment name, then delete it
ASSIGNMENT=$(az rest --method GET \
  --url "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/<your-sentinel-rg>/providers/Microsoft.ManagedServices/registrationAssignments?api-version=2022-10-01" \
  --query "value[0].name" -o tsv)

az rest --method DELETE \
  --url "https://management.azure.com/subscriptions/<sub-id>/resourceGroups/<your-sentinel-rg>/providers/Microsoft.ManagedServices/registrationAssignments/${ASSIGNMENT}?api-version=2022-10-01"
```

---

## Files

| File | Purpose |
|------|---------|
| `main.bicep` | Source of truth — subscription-scoped Lighthouse delegation (definition + RG assignment). |
| `assignment.bicep` | Nested module — creates the registration assignment in the target resource group. |
| `azuredeploy.json` | Compiled ARM template used by the **Deploy to Azure** button. |
| `azuredeploy.parameters.json` | Sample parameters (placeholder GUIDs — edit before CLI deploy). |
| `createUiDefinition.json` | Portal form for the guided **Deploy to Azure** experience. |
| `LICENSE` | MIT. |

---

## References

- [Azure Lighthouse documentation](https://learn.microsoft.com/azure/lighthouse/)
- [Onboard a resource group to Azure Lighthouse](https://learn.microsoft.com/azure/lighthouse/how-to/onboard-customer)
- [Eligible authorizations (JIT / PIM) in Lighthouse](https://learn.microsoft.com/azure/lighthouse/how-to/create-eligible-authorizations)
- [Microsoft Sentinel roles and permissions](https://learn.microsoft.com/azure/sentinel/roles)
- [Azure Lighthouse samples](https://github.com/Azure/Azure-Lighthouse-samples)

---

*Community accelerator — not an official Microsoft product. Provided as-is under the MIT License.*
