################################################
#
# INPUT
#
################################################

Param (

     [string]$fileToUpload
    ,[string]$scriptPath

)

<#
$scriptPath= "C:\Users\Florian\Desktop\20200626\CR"
$fileToUpload= "C:\Users\Florian\Desktop\20200626\CR\Data Grid\Data Grid.csv"
#>

################################################
#
# CALL
#
################################################

$params = [hashtable]@{
	Path = "$( $fileToUpload )"
    scriptPath = "$( $scriptPath )"
}

Set-Location -Path $scriptPath
.\cleverreach__20__upload_list.ps1 -params $params

