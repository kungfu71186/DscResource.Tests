
$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'New-DscResourceCommentBasedHelp' -ModuleRoot $PSScriptRoot

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
    This script will output a hash table with multi-line string that include
    an empty .SYNOPSIS and each .PARAMETER value

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

    Import-Module -Name (
        Join-Path -Path $PSScriptRoot -ChildPath 'MofHelper.psm1'
    )

    Import-Module -Name (
        Join-Path -Path $PSScriptRoot -ChildPath 'Get-DSCResourceParameters.psm1'
    )

    Import-Module -Name (
        Join-Path -Path $PSScriptRoot -ChildPath 'DscResourceCommentHelper.psm1'
    )
    
    $resourceFiles = Get-ResourceFiles $ResourceName
    
    $moduleParameters = Get-DSCResourceParameters $resourceFiles.ModuleFile
    $schemaParameters = Get-MofSchemaObject -FileName $resourceFiles.SchemaFile

    $outputStringsForEachFunction = @{}
    $tab = [System.String]::new(' ',4)
    foreach($function in $moduleParameters.Keys){
        Write-Verbose -Message (
            $script:localizedData.VerboseFunctionComments -f $function
        )

        $stringBuilder = New-Object -TypeName System.Text.StringBuilder

        # Start Synopsis
        $null   = $stringBuilder.AppendLine('<#')
        $null   = $stringBuilder.AppendLine($tab + '.SYNOPSIS')
        $null   = $stringBuilder.AppendLine($tab + $tab + 'Synopsis here')
        $null   = $stringBuilder.AppendLine('')

        # Add each parameter
        foreach($parameter in $moduleParameters[$function]){
            $parameterName   = $parameter.Name.VariablePath.UserPath
            $getMOFParameter = $schemaParameters.Attributes | Where-Object {
                $PSItem.Name -eq $parameterName
            }

            $null = $stringBuilder.AppendLine($tab + '.PARAMETER ' + $parameterName)
            $null = $stringBuilder.AppendLine($tab + $tab + $getMOFParameter.Description)
            $null = $stringBuilder.AppendLine('')
        }

        $null = $stringBuilder.AppendLine("#>")
        $outputStringsForEachFunction[$function] = $stringBuilder.ToString()
    }

    return $outputStringsForEachFunction
}
