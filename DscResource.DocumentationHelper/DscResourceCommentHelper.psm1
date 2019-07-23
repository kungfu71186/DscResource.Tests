
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

Export-ModuleMember -Function *
