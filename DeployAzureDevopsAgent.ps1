param(
    [string] $preferences = "./Preferences/Dev.psm1"
)

Import-Module $Preferences -force

Add-Type -AssemblyName System.Web

Function ToParamsFilePath([string] [Parameter(Position=0, ValueFromPipeline=$true)] $Filename)
{
    return join-path -Path "./Parameters" -ChildPath $Filename
}

$webClient = New-Object -TypeName System.Net.WebClient
$webClient.Proxy.Credentials = [System.Net.CredentialCache]::DefaultNetworkCredentials
Write-Host "Logging In to Azure......"

try
{
# Login (logs for all powershell sessions)
Connect-AzAccount -Tenant $tenantId -Subscription $subscriptionId
Write-Host "Logged In to Azure"

$resourceGroup = New-AzDeployment -Location $defaultLocation -TemplateFile "./ARM/CreateResourceGroup.json" -TemplateParameterFile("ResourceGroup.parameters.json" | ToParamsFilePath)

$resourceGroupName = $resourceGroup.Parameters['rgName'].Value
Write-Host "Resource Group $resourceGroupName Deployed"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./ARM/ResourceGroupPolicy.json"
Write-Host "Storage account policy applied to the resource group"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./ARM/VirtualNetwork.json" -TemplateParameterFile("VirtualNetwork.parameters.json" | ToParamsFilePath)
Write-Host "Virtual Network, Subnet and associated NSG Deployed"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./ARM/Storage.json" -TemplateParameterFile ("Storage.parameters.json" | ToParamsFilePath)
Write-Host "Storage Account with PrivateEndpoint Deployed"

New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile "./ARM/VirtualMachineScaleSet.json" -TemplateParameterFile ("VirtualMachineScaleSet.parameters.json" | ToParamsFilePath)
Write-Host "VMSS deployed"
} 
catch 
{
    #Catch general exceptions and ensure proper debug logging is output.
    Write-Host "Something went wrong"
    Write-Host $_.ScriptStackTrace
    Write-Host $_.Exception
    Write-Host $_.ErrorDetails
}
finally 
{
    #Logout a connected azure account.
    Write-Host "Logging out of Azure"
   # Disconnect-AzAccount
}