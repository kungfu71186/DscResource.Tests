<#
.SYNOPSIS
    Get-DSCResourceParameters is used to get all the parameters that belong
    to a specific DSC resource and a specific function in that resource.

.DESCRIPTION
    Uses AST to parse a DSC Resource module to get the parameters from it. 

.PARAMETER ResourceName
    The resource module name or full path to the .psm1 file to process

.PARAMETER FunctionNames
    This gets the parameters for the functions inside the resource.
    By default this would be:
    'Get-TargetResource', 'Test-TargetResource', 'Set-TargetResource'

.OUTPUTS
    This script will output a hashtable with the function and each parameter the
    function has. @{} = [System.Management.Automation.Language.ParameterAst[]]

.EXAMPLE
    This example parses a psm1 file

    Get-DSCResourceParameters -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1
    Get-DSCResourceParameters -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1 `
        -FunctionName 'Get-TargetResource'

#>
function Get-DSCResourceParameters
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

    Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'DscResourceCommentHelper.psm1')
    $resourceFiles = Get-ResourceFiles  $ResourceName

    $resourceAST = ConvertTo-ParsedAST -ResourceName $resourceFiles.ModuleFile

    Write-Verbose ('Parsing functions: {0}' -f ($FunctionNames -join ', '))
    $functionDefinitionAst = $resourceAST.FindAll(
        {
            param($Item)
            return (
                $Item -is [System.Management.Automation.Language.FunctionDefinitionAst] -And 
                $Item.Name -in $FunctionNames
            )
        },
        $true
    )

    # Check if we found all the functions, if not, show warning
    if ($functionDefinitionAst.Count -lt 1)
    {
        throw ('Could not find any of functions: "{0}" in the resource "{1}"' -f ($FunctionNames -join ','), $ResourceName)
    }
    else
    {
        $missingFunctions = Compare-Object -ReferenceObject $FunctionNames -DifferenceObject $functionDefinitionAst.Name
        $foundFunctions = Compare-Object -ReferenceObject $FunctionNames -DifferenceObject $functionDefinitionAst.Name -IncludeEqual -ExcludeDifferent
        if ($missingFunctions)
        {
            Write-Warning (
                'Could not find the following functions: [{0}], but will continue with the ones we did find: [{1}]' -f (
                    ($missingFunctions.InputObject -join ', '), 
                    ($foundFunctions.InputObject -join ', ')
                )
            )
        }
    }

    Write-Verbose 'Parsing parameters for each function'
    $parameterDictionary = @{}
    $functionDefinitionAst | ForEach-Object {
        $functionName  = $PSItem.Name
        Write-Verbose ('Attempting to find the parameters for the "{0}" function' -f $functionName)
        $parameterDictionary[$functionName] = @()

        $functionParameters = $PSItem.Find(
            {
                param($Item)
                return (
                    $Item -is [System.Management.Automation.Language.ParamBlockAst]
                )
            },
            $true
        )

        if ($functionParameters.Count -lt 1)
        {
            Write-Error 'No parameters found for "{0}"' -f $functionName
            continue
        }

        $parameterDictionary[$functionName] = $functionParameters.Parameters
    }

    return $parameterDictionary
}

<#
.SYNOPSIS
    ConvertTo-ParsedAST

.DESCRIPTION
    This will check if the resource file is specified and if not, it will get 
    the file from the resource name 

.PARAMETER ResourceName
    The resource module name or full path to the .psm1 file to process

.OUTPUTS
    This script will output an AST parsed file

#>
Function ConvertTo-ParsedAST
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ResourceName
    )

    $getModuleParameters = @{
        Name          = $ResourceName
        ListAvailable = $True
    }

    $parseErrors = $null
    $astResourceParsed = $null
    Write-Verbose ('Retreiving module information for: {0}.' -f `
        $getModuleParameters.Name)
    
    if ($moduleInfo = Get-Module @getModuleParameters)
    {
        $astResourceParsed = [System.Management.Automation.Language.Parser]::ParseFile(
            $getModuleParameters.Name, [ref] $null, [ref] $parseErrors
        )
    }
    else
    {
        throw ('Unable to get the information for the "{0}" resource.' `
            -f $ResourceName)
    }

    if ($parseErrors.Count -ne 0) {
        throw (
            'Parsing errors detected when parsing file: {0} | {1}' `
                -f $getModuleParameters.Name, $parseErrors
        )
    }
   
    return $astResourceParsed
}


Export-ModuleMember -Function Get-DSCResourceParameters