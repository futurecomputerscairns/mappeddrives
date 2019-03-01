Param (
       [string]$organisation = ""
       )

function CreateITGItem ($resource, $body) {
    $item = Invoke-RestMethod -Method POST -ContentType application/vnd.api+json -Uri $ITGbaseURI/$resource -Body $body -Headers $headers
    return $item
}

$assettypeID = 120571
$ITGbaseURI = "https://api.itglue.com"

 
$headers = @{
    "x-api-key" = $key
}

Write-Host Attempting match of ITGlue Company using name $organisation -ForegroundColor Green

$attempted_match = Get-ITGlueOrganizations -filter_name "$organisation"

if($attempted_match.data[0].attributes.name -eq $organisation) {
            Write-Host "Auto-match of ITGlue company successful." -ForegroundColor Green

            $ITGlueOrganisation = $attempted_match.data.id
}
            else {
            Write-Host "No auto-match was found. Please pass the exact name in ITGlue to -organization <string>" -ForegroundColor Red
            Exit
            }

#Import the required module GroupPolicy
$drivearray = @()
try
{
Import-Module GroupPolicy -ErrorAction Stop
}
catch
{
throw "Module GroupPolicy not Installed"
}
        $GPO = Get-GPO -All
 
        foreach ($Policy in $GPO){
 
                $GPOID = $Policy.Id
                $GPODom = $Policy.DomainName
                $GPODisp = $Policy.DisplayName
 
                 if (Test-Path "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml")
                 {
                     [xml]$DriveXML = Get-Content "\\$($GPODom)\SYSVOL\$($GPODom)\Policies\{$($GPOID)}\User\Preferences\Drives\Drives.xml"
 
                            foreach ( $drivemap in $DriveXML.Drives.Drive ){

                                    $GPOName = $GPODisp
                                    $DriveLetter = $drivemap.Properties.Letter + ":"
                                    $DrivePath = $drivemap.Properties.Path
                                    $DriveAction = $drivemap.Properties.action.Replace("U","Update").Replace("C","Create").Replace("D","Delete").Replace("R","Replace")
                                    $DriveLabel = $drivemap.Properties.label
                                    $DrivePersistent = $drivemap.Properties.persistent.Replace("0","False").Replace("1","True")
                                    [string]$DriveFilterGroup = $drivemap.Filters.FilterGroup.Name
 
                                    $Object = New-Object PSObject 
                                    $object | Add-Member -MemberType NoteProperty -Name GPOName -Value $GpoName
                                    $object | Add-Member -MemberType NoteProperty -Name DriveLetter -Value $DriveLetter
                                    $object | Add-Member -MemberType NoteProperty -Name DrivePath -Value $DrivePath
                                    $object | Add-Member -MemberType NoteProperty -Name DriveAction -Value $DriveAction
                                    $object | Add-Member -MemberType NoteProperty -Name DriveLabel -Value $DriveLabel
                                    $object | Add-Member -MemberType NoteProperty -Name DrivePersistent -Value $DrivePersistent
                                    $object | Add-Member -MemberType NoteProperty -Name DriveFilterGroup -Value $DriveFilterGroup
                                    $drivearray += $Object
                                }
                            }
                }
        
 foreach ($obj in $drivearray){
    
    $body = @{
        data = @{
            type       = "flexible-assets"
            attributes = @{
                "organization_id"           = $ITGlueOrganisation
                "flexible_asset_type_id"    = $assettypeID
                traits                      = @{
                    "drive-letter"          = $obj.DriveLetter
                    "drive-label"           = $obj.DriveLabel
                    "drive-path"            = $obj.DrivePath
                    "item-level-targetting" = $obj.DriveFilterGroup

                }
            }
        }
 }
    
    $tenantAsset = $body | ConvertTo-Json -Depth 10


CreateITGItem -resource flexible_assets -body $tenantAsset
Write-Host "Created Mapped Drive Object for $($obj.DriveLabel)"
}

