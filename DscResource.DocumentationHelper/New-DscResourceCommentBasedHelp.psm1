<#
.SYNOPSIS
    New-DscResourceCommentBasedHelp will generate the comment based help based
    on the parameters and mof schema

.DESCRIPTION
    New-DscResourceCommentBasedHelp will parse the MOF schema file and compare
    that to the function within the DSC resource and then generate a comment
    based help section to place before the Function. This will take the
    descriptions from the mof and add them as parameters and a description for
    each parameter that is used in the function. The only thing it won't be able
    to do is add a SYNOPSIS statement

.PARAMETER ResourceName
    The resource module name or full path to the .psm1 or mof file to process.
    This can be the directory where the .psm1 or .mof file resides or one of the
    files themselves. This can also be the resource name if the resource is
    installed on the computer

.PARAMETER FunctionNames
    This gets the parameters for the functions inside the resource.
    By default this would be:
    'Get-TargetResource', 'Test-TargetResource', 'Set-TargetResource'

.OUTPUTS
    This script will output a multi-line string with .SYNOPSIS and
    each .PARAMETER value

.EXAMPLE
    This example parses a psm1 file

    New-DscResourceCommentBasedHelp -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1
    New-DscResourceCommentBasedHelp -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.mof
    New-DscResourceCommentBasedHelp -ResourceName C:\DSC\MSFT_xAD
    Get-DSCResourceParameters -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1 `
        -FunctionName 'Get-TargetResource'

#>
Function New-DscResourceCommentBasedHelp
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ResourceName,

        [String[]]
        $FunctionNames = @(
            'Get-TargetResource'
            'Test-TargetResource'
            'Set-TargetResource'
        )
    )

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'MofHelper.psm1')
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Get-DSCResourceParameters.psm1')
    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResourceCommentHelper.psm1')
    
    $resourceFiles = Get-ResourceFiles $ResourceName
    
    $moduleParameters = Get-DSCResourceParameters $resourceFiles.ModuleFile
    $schemaParameters = Get-MofSchemaObject -FileName $resourceFiles.SchemaFile
    
    $outputStrings = @{}
 
    foreach($function in $moduleParameters.Keys){
        Write-Verbose ('Creating the comment help based section for the function {0}' -f $function)
        $output = New-Object -TypeName System.Text.StringBuilder
        $null   = $output.Append("<# ").AppendLine($function)
        $null   = $output.AppendLine("    .SYNOPSIS")
        $null   = $output.AppendLine("        Add Synopsis here`n")

         foreach($parameter in $moduleParameters[$function]){
            $parameterName   = $parameter.Name.VariablePath.UserPath
            $getMOFParameter = $schemaParameters.Attributes | Where-Object {$_.Name -eq $parameterName}
            $null            = $output.Append("    .PARAMETER ").AppendLine($parameterName)
            $null            = $output.AppendLine("        $($getMOFParameter.Description)`n")
         }

         $null = $output.AppendLine("#>")
         $outputStrings[$function] = $output.ToString()
    }

    $outputStrings
}