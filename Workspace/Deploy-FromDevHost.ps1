Connect-AzAccount -UseDeviceAuthentication
Select-AzSubscription -SubscriptionId 'abce806a-805f-46ce-a94b-03e660b48e1c' # CA Lab

New-AzSubscriptionDeployment -Location uksouth -TemplateFile './main.bicep' -TemplateParameterFile './parameters.json'