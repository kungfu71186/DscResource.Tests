
$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'Get-DSCResourceParameters' -ModuleRoot $PSScriptRoot

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

    Import-Module -Name (
        Join-Path -Path $PSScriptRoot -ChildPath 'DscResourceCommentHelper.psm1'
    )
    $resourceFiles = Get-ResourceFiles  $ResourceName

    $resourceAST = ConvertTo-ParsedAST -ResourceName $resourceFiles.ModuleFile

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingFunctions -f ($FunctionNames -join ', ')
    )
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
        throw (
            $script:localizedData.DidNotFindAnyFunctions -f (
                $FunctionNames -join ','
            ), $ResourceName
        )
    }
    else
    {
        $compareParameters = @{
            ReferenceObject  = $FunctionNames
            DifferenceObject = $functionDefinitionAst.Name
        }
        $missingFunctions = Compare-Object @compareParameters
        $foundFunctions   = Compare-Object  @compareParameters -IncludeEqual -ExcludeDifferent
        if ($missingFunctions)
        {
            Write-Warning -Message (
                $script:localizedData.DidNotFindFunction -f (
                    ($missingFunctions.InputObject -join ', '), 
                    ($foundFunctions.InputObject -join ', ')
                )
            )
        }
    }

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingParameters -f (
            $foundFunctions.InputObject -join ', '
        )
    )
    $parameterDictionary = @{}
    $functionDefinitionAst | ForEach-Object {
        $functionName  = $PSItem.Name
        Write-Verbose -Message (
            $script:localizedData.VerboseFindParameters -f $functionName
        )
        
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
            Write-Error -Message (
                $script:localizedData.NoParametersFound -f $functionName
            )
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
    Write-Verbose -Message (
        $script:localizedData.GetModuleInfo -f $getModuleParameters.Name
    )
    
    if ($moduleInfo = Get-Module @getModuleParameters)
    {
        $astResourceParsed = [System.Management.Automation.Language.Parser]::ParseFile(
            $getModuleParameters.Name, [ref] $null, [ref] $parseErrors
        )
    }
    else
    {
        throw ($script:localizedData.ErrorGetModuleInfo -f $ResourceName)
    }

    if ($parseErrors.Count -ne 0) {
        throw (
            $script:localizedData.ErrorParseAST -f $getModuleParameters.Name, $parseErrors
        )
    }
   
    return $astResourceParsed
}


Export-ModuleMember -Function Get-DSCResourceParameters
