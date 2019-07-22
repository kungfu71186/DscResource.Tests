
Function Get-ResourceFiles
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [String]
        $ResourceName
    )

    $returnFiles = @{
        SchemaFile = $null
        ModuleFile = $null
    }

    if (Test-Path -Path $ResourceName -ErrorAction SilentlyContinue)
    {
        if ($ResourceName -match '.*.schema.mof$')
        {
            $returnFiles.SchemaFile = $ResourceName
            $returnFiles.ModuleFile = $ResourceName -replace '.schema.mof', '.psm1'
        }
        elseif ($ResourceName -match '.*.psm1$')
        {
            $returnFiles.SchemaFile = $ResourceName -replace '.psm1', '.schema.mof'
            $returnFiles.ModuleFile = $ResourceName
        }
        elseif (Test-Path -Path $ResourceName -PathType Container)
        {
            # It's a directory, let's see if we can find the schema and psm files
            $files = Get-ChildItem "C:\Users\martinezm\source\repos\xActiveDirectory\DSCResources\MSFT_xADKDSKey"

            $returnFiles.SchemaFile = (
                Get-ChildItem "C:\Users\martinezm\source\repos\xActiveDirectory\DSCResources\MSFT_xADKDSKey" -Filter *.schema.mof
            ).FullName

            $returnFiles.ModuleFile = (
                Get-ChildItem "C:\Users\martinezm\source\repos\xActiveDirectory\DSCResources\MSFT_xADKDSKey" -Filter *.psm1
            ).FullName

            if ($returnFiles.SchemaFile -and $returnFiles.ModuleFile)
            {
                Write-Verbose ('Found the resource files in the directory  "{0}"' -f $ResourceName)
            }
            else
            {
                throw ('Could not find the resource files in the directory "{0}"' -f $ResourceName)
            }
        }
        else
        {
            throw ('The file "{0}" is an unrecognizable file type' -f $ResourceName)
        }

        Write-Verbose ('Module found: {0}.' -f $ResourceName)
    }
    else
    {
        # The resource name may have been specified instead of the filename
        if ($resourceInfo = Get-DscResource -Name $ResourceName -ErrorAction SilentlyContinue)
        {
            $returnFiles.SchemaFile = $resourceInfo.Path -replace '.psm1', '.schema.mof'
            $returnFiles.ModuleFile = $resourceInfo.Path
        }
        else
        {
            throw ('Unable to get the information for the "{0}" resource.' -f $ResourceName)
        }
    }

    return $returnFiles
}

Export-ModuleMember -Function *