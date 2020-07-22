
################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\Users\Florian\Desktop\20200626\CR"
	    Path= "C:\Users\Florian\Desktop\20200626\CR\Data Grid\Data Grid.csv"
    }
}


################################################
#
# NOTES
#
################################################

<#


#>

################################################
#
# SCRIPT ROOT
#
################################################

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "CLVRUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}



################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$auth = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
$header = @{
    "Authorization" = $auth
}

$contentType = "application/json; charset=utf-8"

$apiRoot = $settings.base


<#
switch ( $uploadMethod ) {

    "datelist" {

        #-----------------------------------------------
        # CREATE NEW LIST WITH TIMESTAMP
        #-----------------------------------------------

        # do something

    }

    "samegroup" {

        #-----------------------------------------------
        # GET GROUP
        #-----------------------------------------------

        $object = "groups"
        $endpoint = "$( $apiRoot )$( $object ).json"
        $res = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header



        #-----------------------------------------------
        # LOAD ACTIVE RECEIVERS AND DEACTIVATE THEM
        #-----------------------------------------------

        $pagesize = 2
        $groups | ForEach { 
            
            $group = $_

            # load stats for active receivers per list -> stats or not refreshed within seconds!
            #$endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/stats"
            #$stats = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header

            # load active receivers
            $receivers = @()
            $page = 0
            Do {
                $endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/receivers?pagesize=$( $pagesize )&detail=0&page=$( $page )"        
                $receivers += Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header
                $page += 1
            } while ( $receivers.Count -eq $pagesize )

            # deactivate receivers
            $pages = [math]::Ceiling( $receivers.Count / $pagesize )    
            if ( $pages -gt 0 ) {
                $update = @()
                0..( $pages - 1 ) | ForEach {
                    $page = $_
                    $skip = $page * $pagesize 
                    $postData = $receivers | select id, @{name="deactivated";expression={ "0" }} -First $pagesize -Skip $skip
                    $body = @{"postdata"=$postData} | ConvertTo-Json
                    $endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/receivers/update"
                    $update += Invoke-RestMethod -Method Put -Uri $endpoint -Headers $header -Body $body
                }
                $update
            }

            # check again, if there is someone active left
            

        }


    }

}

#>


#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

$file = Get-Item -Path $params.Path
$dataCsv = import-csv -Path $file.FullName -Delimiter "`t" -Encoding UTF8
$filename = $file.Name -replace $file.Extension


#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$requiredFields = @("email")

# Load global attributes

$object = "attributes"
$endpoint = "$( $apiRoot )$( $object ).json"
$globalAttributes = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header  -Verbose -ContentType "application/json; charset=utf-8"
 
# TODO [ ] Implement re-using a group (with deactivation of receivers and comparation of local fields)

$globalAttributesNames = $globalAttributes | where { $_.name -notin $requiredFields }
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 

# Check if email field is present

$equalWithRequirements = Compare-Object  -ReferenceObject $csvAttributesNames.Name -DifferenceObject $requiredFields -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }

if ( $equalWithRequirements.count -eq $requiredFields.Count ) {
    # Required fields are all included
} else {
    # Required fields not equal -> error!
}

# Compare columns
$differences = Compare-Object -ReferenceObject $globalAttributesNames -DifferenceObject ( $csvAttributesNames  | where { $_.name -notin $requiredFields } ) -Property Name -IncludeEqual
$colsEqual = $differences | where { $_.SideIndicator -eq "==" } 
$colsInGlobalButNotCsv = $differences | where { $_.SideIndicator -eq "<=" } 
$colsInCsvButNotGlobal = $differences | where { $_.SideIndicator -eq "=>" }


#-----------------------------------------------
# CREATE GROUP
#-----------------------------------------------

$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json"
$body = @{"name" = "$( $filename ) $( [datetime]::Now.ToString("yyyyMMdd HHmmss") )" } # $processId.guid
$bodyJson = $body | ConvertTo-Json
$newGroup = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
 

#-----------------------------------------------
# CREATE LOCAL ATTRIBUTES
#-----------------------------------------------

$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $newGroup.id )/attributes"
$newAttributes = @()
$colsInCsvButNotGlobal | ForEach {

    $newAttributeName = $_.Name

    $body = @{
        "name" = $newAttributeName
        "type" = "text"                     # text|number|gender|date
        #"description" = "Secret identity"   # optional 
        #"preview_value" = "real name"       # optional
        #"default_value" = "Bruce Wayne"     # optional
    }
    $bodyJson = $body | ConvertTo-Json

    $newAttributes += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 

}


#-----------------------------------------------
# TRANSFORM UPLOAD DATA
#-----------------------------------------------

# TODO [ ] put this into another type of loop to build a max. no of records per batch

# to set receivers active, do something like:
<#
{ "postdata":[
    {"id"="5","deactivated"="0"},{"id"="119","deactivated"="0"}
]}
#>

$uploadObject = @()
For ($i = 0 ; $i -lt $dataCsv.count ; $i++ ) {

    $uploadEntry = [PSCustomObject]@{
        email = $dataCsv[$i].email
        global_attributes = [PSCustomObject]@{}
        attributes = [PSCustomObject]@{}
    }

    # Global attributes
    $colsEqual | ForEach {
        $attrName = $_.Name
        $uploadEntry.global_attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrName
    }

    # Local attributes
    $newAttributes | ForEach {
        $attrName = $_.name
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrName
    }

    <#
        #$props = Get-Member -InputObject $dataCsv[$i] -MemberType NoteProperty | where { $_.Name -ne "email" }
    ForEach($prop in $props) {
        $propName = $prop.Name
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $dataCsv[$i].$propName
    }
    #>

    $uploadObject += $uploadEntry
    
}


#-----------------------------------------------
# UPSERT DATA INTO GROUP
#-----------------------------------------------

$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $newGroup.id )/receivers/upsert"
$bodyJson = $uploadObject | ConvertTo-Json
$upload = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 


exit 0


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################
<#
# count the number of successful upload rows
$recipients = $importResults

# put in the source id as the listname
$transactionId = $waveId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

#>