################################################
#
# INPUT
#
################################################

Param (
    [string]$file
)


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $file = "D:\Apteco\Publish\Handel\system\deliveries\testfile.csv"
}


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
    $scriptPath = "<scriptPath>"
}
Set-Location -Path $scriptPath



################################################
#
# SETTINGS
#
################################################

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$logfile = $settings.logfile

# sqlserver
$mssqlConnectionString = Get-SecureToPlaintext -String $settings.connectionString

# sql queries
$deliveryMetadataSql = ".\sql\100_load_delivery_metadata.sql"


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# START CHECK
#
################################################

$fileExists = Check-Path -Path $file

if ( !$fileExists ) {
    Exit 1
}

# get the input file
$fileItem = Get-Item -Path $file

# log
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`t--------------------------------" >> $logfile
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tUsing: $( $fileItem.FullName )" >> $logfile


################################################
#
# LOAD DELIVERY METADATA
#
################################################

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tLoad delivery metadata from SQLSERVER" >> $logfile

# prepare query
$deliverySql = Get-Content -Path "$( $deliveryMetadataSql )" -Encoding UTF8
$deliverySql = $deliverySql -replace "#FILE#", $fileItem.Name

try {

    # build connection
    $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()
    
    # execute command
    $mssqlCommand = $mssqlConnection.CreateCommand()
    $mssqlCommand.CommandText = $deliverySql
    $mssqlResult = $mssqlCommand.ExecuteReader()
    
    # load data
    $deliveryMetadata = new-object "System.Data.DataTable"
    $deliveryMetadata.Load($mssqlResult)

} catch [System.Exception] {

    $errText = $_.Exception
    $errText | Write-Output
    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile

} finally {
    
    # close connection
    $mssqlConnection.Close()

}

# load variables from result
$deliveryKey = $deliveryMetadata[0].DeliveryKey
$parameters = $deliveryMetadata[0].Parameters

# log 
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tGot back delivery key: $( $deliveryKey )" >> $logfile
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tGot back parameters: $( $parameters )" >> $logfile


################################################
#
# LOAD OUTPUT FORMAT
#
################################################

$params = New-Object -Type PSCustomObject
$lines = $parameters -split ";"
$lines | ForEach {
    
    $line = $_
    $key,$value = $line -split "=" 
    $params | Add-Member -MemberType NoteProperty -Name $key -Value $value

}

$columns = $params.ClosedLoopLayout -split '|',0,"SimpleMatch"

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tColumns for output: $( $params.ClosedLoopLayout )" >> $logfile


################################################
#
# EXPORT FILE
#
################################################

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile

$exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $columns -writeCount -1 -outputDoubleQuotes $false

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId )!" >> $logfile


################################################
#
# MOVE FILES
#
################################################

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tRenaming and replacing files" >> $logfile

# rename original file first
$destination = $fileItem.FullName
Rename-Item -Path $fileItem -NewName "$( $fileItem.FullName ).tmp"

# get the new item
$fNew = Get-ChildItem -Path ".\$( $exportId )" | select -First 1

# move new file in that place
Move-Item -Path $fNew.FullName -Destination $destination



################################################
#
# FINISH
#
################################################

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tDone with the whole job!" >> $logfile

