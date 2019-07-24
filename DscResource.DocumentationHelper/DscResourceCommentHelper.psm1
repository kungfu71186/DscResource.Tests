
$projectRootPath = Split-Path -Path $PSScriptRoot -Parent
$testHelperPath = Join-Path -Path $projectRootPath -ChildPath 'TestHelper.psm1'
Import-Module -Name $testHelperPath -Force

$script:localizedData = Get-LocalizedData -ModuleName 'DscResourceCommentHelper' -ModuleRoot $PSScriptRoot

<#
.SYNOPSIS
    Get-ResourceFiles will get the mof and module file for a specified resource

.DESCRIPTION
    This will look for the files necassary for a dsc resource and return the
    location of those files. This is mainly used when the files are required for
    parsing and metadata is needed

.PARAMETER ResourceName
    The resource module name, path to the .psm1, path to the .mof, or the
    directory to process

.OUTPUTS
    This script will output a hashtable with SchemaFile and ModuleFile
    @{
        SchemaFile
        ModuleFile
    }

.EXAMPLE
    This example parses a psm1 file and returns both the schema and mof file

    Get-ResourceFiles -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1

#>
Function Get-ResourceFiles
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ResourceName
    )

    if ($ResourceName -match '.*.schema.mof$' -or $ResourceName -match '.*.psm1$')
    {
        if (Test-Path -Path $ResourceName -ErrorAction SilentlyContinue)
        {

            return @{
                SchemaFile = $ResourceName -replace '.psm1', '.schema.mof'
                ModuleFile = $ResourceName -replace '.schema.mof', '.psm1'
            }
        }
        else
        {
            throw ($script:localizedData.ResourceFileNotFound -f $ResourceName)
        }
    }

    if (Test-Path -Path $ResourceName -PathType Container)
    {
        # It's a directory, let's see if we can find the schema and psm files
        $files = Get-ChildItem $ResourceName

        $returnFiles = @{

            SchemaFile = (
                Get-ChildItem $ResourceName -Filter *.schema.mof
            ).FullName

            ModuleFile = (
                Get-ChildItem $ResourceName -Filter *.psm1
            ).FullName
        }

        if ($returnFiles.SchemaFile -and $returnFiles.ModuleFile)
        {
            Write-Verbose -Message (
                $script:localizedData.ResourceFilesFound -f $ResourceName
            )
            
            return $returnFiles
        }
        else
        {
            throw (
                $script:localizedData.ResourceFilesNotFoundInDirectory -f $ResourceName
            )
        }
    }

    # The resource name may have been specified instead of the filename or directory
    if ($resourceInfo = Get-DscResource -Name $ResourceName -ErrorAction SilentlyContinue)
    {
        return @{
            SchemaFile = $resourceInfo.Path -replace '.psm1', '.schema.mof'
            ModuleFile = $resourceInfo.Path
        }
    }

    throw ($script:localizedData.ResourceInfoError -f $ResourceName)
}

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
    $resourceFiles = Get-ResourceFiles  $ResourceName

    $resourceAST = ConvertTo-ParsedAST -ResourceName $resourceFiles.ModuleFile

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingFunctions -f ($FunctionNames -join ', ')
    )

    $functionDefinitionAst = Get-DSCResourceFunctionsFromAST -Ast $resourceAST -FunctionNames $FunctionNames

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingParameters -f (
            $foundFunctions.InputObject -join ', '
        )
    )
    $parameterDictionary = @{}
    # Go through each function and add the parameters for that function
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
    Get-DSCResourceCommentBasedHelp is used to get all the help based comments
    that belong to a specific DSC resource and a specific function in that 
    resource.

.DESCRIPTION
    Uses AST to parse a DSC Resource module to get the help based comments
    from it. 

.PARAMETER ResourceName
    The resource module name or full path to the .psm1 file to process

.PARAMETER FunctionNames
    This gets the parameters for the functions inside the resource.
    By default this would be:
    'Get-TargetResource', 'Test-TargetResource', 'Set-TargetResource'

.OUTPUTS
    This script will output a hashtable with the function and each comment 
    object the function has. @{} = [System.Object]

.EXAMPLE
    This example parses a psm1 file

    Get-DSCResourceCommentBasedHelp -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1
    Get-DSCResourceCommentBasedHelp -ResourceName C:\DSC\MSFT_xAD\MSFT_xAD.psm1 `
        -FunctionName 'Get-TargetResource'

#>
function Get-DSCResourceCommentBasedHelp
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

    $resourceFiles = Get-ResourceFiles  $ResourceName

    $resourceAST = ConvertTo-ParsedAST -ResourceName $resourceFiles.ModuleFile

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingFunctions -f ($FunctionNames -join ', ')
    )

    $functionDefinitionAst = Get-DSCResourceFunctionsFromAST -Ast $resourceAST -FunctionNames $FunctionNames

    Write-Verbose -Message (
        $script:localizedData.VerboseParsingParameters -f (
            $foundFunctions.InputObject -join ', '
        )
    )

    $helpDictionary = @{}
    $functionDefinitionAst | ForEach-Object {
        # https://stackoverflow.com/questions/45929043/get-all-functions-in-a-powershell-script
        # Get the plain string comment block from the AST.
        $functionName = $PSItem.Name
        $commentBlock = $PSItem.GetHelpContent().GetCommentBlock()

        $scriptBlock = [scriptblock]::Create(('
        function {0} {{
            {1}
            param()
        }}' -f $functionName, $commentBlock))
        
        # Dot source the scriptblock in a different scope so we can
        # get the help content but still not pollute the session.
        & {
            . $scriptBlock
    
            $helpObject = Get-Help $functionName
            $helpDictionary[$functionName] = $helpObject
        }       
    }

    return $helpDictionary
}

function Get-DSCResourceFunctionsFromAST
{
    [CmdletBinding()]
    param
    (
        [System.Management.Automation.Language.Ast]
        $Ast,

        [String[]]
        $FunctionNames = @(
            'Get-TargetResource'
            'Test-TargetResource'
            'Set-TargetResource'
        )
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

    return $functionDefinitionAst
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

Export-ModuleMember -Function *
