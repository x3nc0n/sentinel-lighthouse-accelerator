targetScope = 'subscription'

// ============================================================================
// Microsoft Sentinel — Multi-Tenant Lighthouse Accelerator (resource-group delegation)
// ============================================================================
// Delegates a SINGLE resource group (your Microsoft Sentinel RG) to a service
// provider / MSSP tenant using Azure Lighthouse.
//
// Three operator tiers, all granted the SAME standing (always-on) roles, plus a
// just-in-time (PIM) elevation path for Tier 3 only.
//
//   Tier 1 / Tier 2 / Tier 3  ->  standing roles (Responder, Playbook Operator, Reader)
//   Tier 3 only               ->  eligible/PIM roles (Sentinel Contributor, Logic App Contributor)
//
// SCOPE: This is a SUBSCRIPTION-scoped deployment (registration definitions are
// subscription-scope only). The registration ASSIGNMENT is applied to the single
// resource group named in `rgName`, so only that RG is delegated.
//
// DIRECTION: Deployed by an admin of the CUSTOMER tenant (the one that owns the
// Sentinel resource group), granting the PROVIDER tenant access.
// `managedByTenantId` is the PROVIDER (MSSP) tenant — not the customer.
// ============================================================================

@description('Display name of the delegation offer shown in the Azure "Service providers" blade.')
param mspOfferName string = 'Microsoft Sentinel Multi-Tenant Accelerator'

@description('Description of the delegation offer.')
param mspOfferDescription string = 'Delegated Microsoft Sentinel operations on this resource group for a service provider (MSSP). Three operator tiers share standing operational access; Tier 3 can elevate just-in-time to Sentinel Contributor and Logic App Contributor.'

@description('Tenant ID (GUID) of the SERVICE PROVIDER / MSSP tenant whose groups receive delegated access.')
param managedByTenantId string

@description('Name of the target Microsoft Sentinel resource group (in THIS subscription) to delegate.')
param rgName string

@description('Object ID (GUID) of the Tier 1 operators security group in the provider tenant.')
param tier1GroupId string

@description('Object ID (GUID) of the Tier 2 operators security group in the provider tenant.')
param tier2GroupId string

@description('Object ID (GUID) of the Tier 3 operators security group in the provider tenant.')
param tier3GroupId string

@description('Friendly name for the Tier 1 group (shown in the portal delegation view).')
param tier1GroupName string = 'MSSP Tier 1 Operators'

@description('Friendly name for the Tier 2 group.')
param tier2GroupName string = 'MSSP Tier 2 Operators'

@description('Friendly name for the Tier 3 group.')
param tier3GroupName string = 'MSSP Tier 3 Operators'

@description('Standing (always-on) built-in role GUIDs granted to ALL three tiers on the resource group. Defaults: Microsoft Sentinel Responder, Microsoft Sentinel Playbook Operator, Reader. None carry Microsoft.Authorization/*/write, so they are valid for standing delegation.')
param standingRoleDefinitionIds array = [
  '3e150937-b8fe-4cfb-8069-0eaf05ecd056' // Microsoft Sentinel Responder
  '51d6186e-6489-4900-b93f-92e23144cca5' // Microsoft Sentinel Playbook Operator
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' // Reader
]

@description('Built-in role GUIDs that Tier 3 can activate just-in-time (PIM) on the resource group. Defaults: Microsoft Sentinel Contributor, Logic App Contributor.')
param tier3EligibleRoleDefinitionIds array = [
  'ab8e14d6-4a74-4a29-9ba8-549422addade' // Microsoft Sentinel Contributor
  '87a39d53-fc1b-424a-814c-f7e04687dc9e' // Logic App Contributor
]

@description('Maximum PIM activation duration for Tier 3 eligible roles, as an ISO 8601 duration (e.g. PT8H = 8 hours).')
param pimMaxActivationDuration string = 'PT8H'

@description('Require Azure Multi-Factor Authentication when Tier 3 activates an eligible role.')
param pimRequireMfa bool = true

// ----------------------------------------------------------------------------
// Build authorization arrays from the simple tier inputs
// ----------------------------------------------------------------------------
// Standing access: every tier group x every standing role. Bicep does not allow
// nested for-loops in a variable, so we build one array per tier and concat them.
var tier1StandingAuth = [
  for roleId in standingRoleDefinitionIds: {
    principalId: tier1GroupId
    principalIdDisplayName: tier1GroupName
    roleDefinitionId: roleId
  }
]
var tier2StandingAuth = [
  for roleId in standingRoleDefinitionIds: {
    principalId: tier2GroupId
    principalIdDisplayName: tier2GroupName
    roleDefinitionId: roleId
  }
]
var tier3StandingAuth = [
  for roleId in standingRoleDefinitionIds: {
    principalId: tier3GroupId
    principalIdDisplayName: tier3GroupName
    roleDefinitionId: roleId
  }
]
var standingAuthorizations = concat(tier1StandingAuth, tier2StandingAuth, tier3StandingAuth)

// Just-in-time policy applied to every Tier 3 eligible role.
var jitAccessPolicy = {
  multiFactorAuthProvider: pimRequireMfa ? 'Azure' : 'None'
  maximumActivationDuration: pimMaxActivationDuration
}

// Eligible (PIM) access: Tier 3 group x each eligible role.
var eligibleAuthorizations = [
  for roleId in tier3EligibleRoleDefinitionIds: {
    principalId: tier3GroupId
    principalIdDisplayName: tier3GroupName
    roleDefinitionId: roleId
    justInTimeAccessPolicy: jitAccessPolicy
  }
]

// ----------------------------------------------------------------------------
// Registration definition (subscription scope) — describes the offer + access
// ----------------------------------------------------------------------------
resource registrationDefinition 'Microsoft.ManagedServices/registrationDefinitions@2022-10-01' = {
  name: guid(mspOfferName, managedByTenantId, subscription().subscriptionId)
  properties: {
    registrationDefinitionName: mspOfferName
    description: mspOfferDescription
    managedByTenantId: managedByTenantId
    authorizations: standingAuthorizations
    eligibleAuthorizations: eligibleAuthorizations
  }
}

// ----------------------------------------------------------------------------
// Registration assignment (resource-group scope) — delegates ONLY rgName
// ----------------------------------------------------------------------------
module assignment 'assignment.bicep' = {
  name: 'sentinelLighthouseAssignment'
  scope: resourceGroup(rgName)
  params: {
    registrationDefinitionId: registrationDefinition.id
    mspOfferName: mspOfferName
  }
}

// ----------------------------------------------------------------------------
// Outputs
// ----------------------------------------------------------------------------
@description('The delegation offer name as registered.')
output mspOfferName string = mspOfferName

@description('Resource ID of the registration definition.')
output registrationDefinitionId string = registrationDefinition.id

@description('Resource ID of the registration assignment (scoped to the resource group).')
output registrationAssignmentId string = assignment.outputs.registrationAssignmentId

@description('Count of standing authorizations created (tiers x standing roles).')
output standingAuthorizationCount int = length(standingAuthorizations)

@description('Count of Tier 3 eligible (PIM) authorizations created.')
output eligibleAuthorizationCount int = length(eligibleAuthorizations)
