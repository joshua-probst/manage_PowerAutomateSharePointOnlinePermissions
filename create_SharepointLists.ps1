param(
    [Parameter (Mandatory = $true)]
    [string]$spSite = ""
)

Import-Module PnP.PowerShell

Connect-PnPOnline -url $spSite -Interactive -ForceAuthentication

#region
$permissionLevelListName = "Permission_Level"
#get information from sharepoint site 
$allPermissionLevel = Get-PnPRoleDefinition | Select-Object Id, Name

#endregion

function createListinSpSite{
    param(
        [string]$spListName 
    )
    New-PnPList -Title $spListName -Url "lists/$spListName" -Template GenericList -EnableContentTypes | Out-Null
}

function configSpContentTypes{
    param(
    [string]$spContentTypeName,   
    [string]$spListName,
    [array]$spContentTypeFields
    )
    Add-PnPContentType -Name $spContentTypeName | Out-Null

    foreach($spField in $spContentTypeFields){
        Add-PnPFieldToContentType -ContentType $spContentTypeName -Field $spField | Out-Null
    }

    Add-PnPContentTypeToList -List $spListName -ContentType $spContentTypeName -DefaultContentType | Out-Null

    # remove not needed content type in list, we like it clean
    Get-PnPContentType -List $spListName | Where-Object Name -ne $spContentTypeName | Foreach-Object{
        Remove-PnPContentTypeFromList -List $spListName -ContentType $_.Name | Out-Null
    }
}

#region
# create list for stored metadata
try{
    Get-PnPList -Identity $permissionLevelListName | Out-Null
}catch{
    # create list when not in site collection
    createListinSpSite $permissionLevelListName
    
    # create required metadata for list 
    $spPermissionListFields = @()
    $spPermissionListFields += (Add-PnPField -Type Text -InternalName "Permission_Name" -DisplayName "Permission_Name").InternalName
    $spPermissionListFields += (Add-PnPField -Type Number -InternalName "Permission_ID" -DisplayName "Permission_ID").InternalName

    configSpContentTypes -spListName $permissionLevelListName -spContentTypeName $permissionLevelListName -spContentTypeFields $spPermissionListFields

    $viewIdentity = (Get-PnPView -List $permissionLevelListName).Id

    Set-PnPView -List $permissionLevelListName -Identity $viewIdentity -Fields $spPermissionListFields | Out-Null
}
#endregion


#region
# check if permission allready exists in list
$permissionLevelListItems = Get-PnPListItem -List $permissionLevelListName
# create permissionlevel in list
foreach($permission in $allPermissionLevel){
    $permissionId = $permission.Id
    $permissionName = $permission.Name
    if(($permissionLevelListItems).FieldValues.Permission_ID -notcontains $permission.Id){
        Add-PnPListItem -List $permissionLevelListName -Values @{"Title" = "$permissionName"; "Permission_Name"="$permissionName"; "Permission_ID"="$permissionId"} | Out-Null
    }
}
#endregion
