# Contributing

Thanks for your interest in improving the **Microsoft Sentinel Multi-Tenant Lighthouse Accelerator**!
Contributions of all kinds are welcome — bug reports, docs fixes, and template improvements.

## Ground rules

- **`main.bicep` is the source of truth.** Never hand-edit `azuredeploy.json` — it is generated.
- Keep the experience simple: the whole point of this accelerator is that a consumer supplies **three
  group IDs** and the target RG name, nothing more. Avoid reintroducing hand-formatted role arrays as
  required input.
- Preserve the security posture: standing roles must be free of `Microsoft.Authorization/*/write`;
  broader access belongs in the **eligible (PIM)** path.

## Making a change

1. Edit `main.bicep` (and `assignment.bicep` if the RG-scoped assignment changes).
2. Regenerate the ARM template so the **Deploy to Azure** button stays in sync:
   ```bash
   az bicep build --file main.bicep --outfile azuredeploy.json
   ```
3. If you change parameters, update **all** of:
   - `azuredeploy.parameters.json` (sample values)
   - `createUiDefinition.json` (portal form fields **and** the `outputs` block)
   - the parameter table in `README.md`
4. Validate without deploying (requires an Azure subscription you can deploy to):
   ```bash
   az deployment sub validate \
     --location eastus \
     --template-file main.bicep \
     --parameters rgName=<rg> managedByTenantId=<tenant> \
                  tier1GroupId=<g1> tier2GroupId=<g2> tier3GroupId=<g3>
   ```
5. Open a pull request. CI (`.github/workflows/validate.yml`) builds the Bicep and fails if
   `azuredeploy.json` is out of date.

## Role references

Standing and eligible roles follow Microsoft's
[recommended role assignments for Microsoft Sentinel users](https://learn.microsoft.com/en-us/azure/sentinel/roles#recommended-role-assignments-for-microsoft-sentinel-users).
If you change the default roles, update the mapping table in the README to keep that alignment clear.

## Reporting issues

Open a GitHub issue with the template version, the exact `az` command or portal steps, and the full
error text (redact tenant/subscription/group IDs).

By contributing, you agree that your contributions are licensed under the [MIT License](LICENSE).
