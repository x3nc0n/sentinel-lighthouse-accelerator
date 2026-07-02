targetScope = 'resourceGroup'

// Nested module: creates the registration ASSIGNMENT in the target Sentinel
// resource group. Deployed at resource-group scope from the subscription-scoped
// parent (registration definitions are subscription-scope only, assignments are
// applied at the resource-group scope to delegate just that RG).

@description('Resource ID of the parent registration definition (subscription scope).')
param registrationDefinitionId string

@description('Delegation offer name — used to derive a stable assignment GUID.')
param mspOfferName string

resource registrationAssignment 'Microsoft.ManagedServices/registrationAssignments@2022-10-01' = {
  name: guid(resourceGroup().id, mspOfferName)
  properties: {
    registrationDefinitionId: registrationDefinitionId
  }
}

@description('Resource ID of the registration assignment (scoped to this resource group).')
output registrationAssignmentId string = registrationAssignment.id
