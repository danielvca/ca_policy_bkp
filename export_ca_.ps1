#Backup and Export Azure Conditional Access Policies.
# https://azureblog.dev

function GetGraphToken {


Param(
    [parameter(Mandatory = $true)]
    $clientId,
    [parameter(Mandatory = $true)]
    $tenantId,
    [parameter(Mandatory = $true)]
    $clientSecret

    )

    # Construct URI
    $uri = "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token"

    # Construct Body
    $body = @{
        client_id     = $clientId
        scope         = "https://graph.microsoft.com/.default"
        client_secret = $clientSecret
        grant_type    = "client_credentials"
    }

    # Get OAuth 2.0 Token
    $tokenRequest = Invoke-WebRequest -Method Post -Uri $uri -ContentType "application/x-www-form-urlencoded" -Body $body -UseBasicParsing

    # Access Token
    $token = ($tokenRequest.Content | ConvertFrom-Json).access_token

    #Returns token
    return $token
}

function RunQueryandEnumerateResults {

    Param(
        [parameter(Mandatory = $true)]
        [String]
        $apiUri,
        [parameter(Mandatory = $true)]
        $token
 
    )
 
    #Run Graph Query
    $Results = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($Token)" } -Uri $apiUri -Method Get)
    #Output Results for debug checking
    #write-host $results
 
    #Begin populating results
    $ResultsValue = $Results.value
 
    #If there is a next page, query the next page until there are no more pages and append results to existing set
    if ($results."@odata.nextLink" -ne $null) {
        write-host enumerating pages -ForegroundColor yellow
        $NextPageUri = $results."@odata.nextLink"
        ##While there is a next page, query it and loop, append results
        While ($NextPageUri -ne $null) {
            $NextPageRequest = (Invoke-RestMethod -Headers @{Authorization = "Bearer $($Token)" } -Uri $NextPageURI -Method Get)
            $NxtPageData = $NextPageRequest.Value
            $NextPageUri = $NextPageRequest."@odata.nextLink"
            $ResultsValue = $ResultsValue + $NxtPageData
        }
    }
 
    ##Return completed results
    return $ResultsValue
 
     
}
 
function Report-ConditionalAccess{
 
    <#
    .SYNOPSIS
    Returns a report of Conditional Access Policies in a tenent
     
    #>
 
    # Application (client) ID, tenant ID and secret
    Param(
        [parameter(Mandatory = $true)]
        $clientId,
        [parameter(Mandatory = $true)]
        $tenantId ,
        [parameter(Mandatory = $true)]
        $clientSecret
 
    )
 
    $apiUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    $token = GetGraphToken -clientId $clientId -tenantId  $tenantId -clientSecret $clientSecret
 
    $Policies = RunQueryandEnumerateResults -apiuri $apiUri -token $token
 
 
 
    foreach($policy in $policies){
 
        $policy | convertto-json | out-file ("$($policy.displayName).json").replace('[','').replace(']','').replace('/','')
    }
 
}