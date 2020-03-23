function Get-DscConfigurationVersion
{
    New-Object -TypeName PSObject -Property @{
        Version = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name Version
        Environment = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name Environment
        GitCommitId = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name GitCommitId
        BuildDate = Get-ItemPropertyValue -Path HKLM:\SOFTWARE\DscTagging -Name BuildDate
    }
}

function Test-DscConfiguration {
    PSDesiredStateConfiguration\Test-DscConfiguration -Detailed -Verbose
}

function Update-DscConfiguration {
    PSDesiredStateConfiguration\Update-DscConfiguration -Wait -Verbose
}

function Get-DscLcmControllerSummary {
    Import-Csv -Path C:\ProgramData\Dsc\LcmController\LcmControllerSummary.txt
}

function Start-DscConfiguration {
    PSDesiredStateConfiguration\Start-DscConfiguration -UseExisting -Wait -Verbose
}

#-------------------------------------------------------------------------------------------

Configuration DscTagging {
    Param(
        [Parameter(Mandatory)]
        [System.Version]$Version,

        [Parameter(Mandatory)]
        [string]$Environment
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration
    Import-DscResource -ModuleName PSDesiredStateConfiguration
    Import-DscResource -ModuleName JeaDsc

    $gitCommitId = git log -n 1 *>&1
    $gitCommitId = if ($gitCommitId -like '*fatal*') {
        'NoGitRepo'
    }
    else {
        $gitCommitId[0].Substring(7)
    }

    xRegistry DscVersion {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscTagging'
        ValueName = 'Version'
        ValueData = $Version
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscEnvironment {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscTagging'
        ValueName = 'Environment'
        ValueData = $Environment
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscGitCommitId {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscTagging'
        ValueName = 'GitCommitId'
        ValueData = $gitCommitId
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscBuildDate {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscTagging'
        ValueName = 'BuildDate'
        ValueData = Get-Date
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    xRegistry DscBuildNumber {
        Key       = 'HKEY_LOCAL_MACHINE\SOFTWARE\DscTagging'
        ValueName = 'BuildNumber'
        ValueData = ">>$($env:BHBuildNumber)<<" #the format supports finding the BuildNumber without using a MOF parser 
        ValueType = 'String'
        Ensure    = 'Present'
        Force     = $true
    }

    $visibleFunctions = 'Test-DscConfiguration', 'Get-DscConfigurationVersion', 'Update-DscConfiguration', 'Get-DscLcmControllerSummary', 'Start-DscConfiguration'
    $functionDefinitions = @()
    foreach ($visibleFunction in $visibleFunctions) {
        $functionDefinitions += @{
            Name = $visibleFunction
            ScriptBlock = (Get-Command -Name $visibleFunction).ScriptBlock
        } | ConvertTo-Expression
    }

    JeaRoleCapabilities ReadDiagnosticsRole
    {
        Path = 'C:\Program Files\WindowsPowerShell\Modules\DscDiagnostics\RoleCapabilities\ReadDiagnosticsRole.psrc'
        VisibleFunctions = $visibleFunctions
        FunctionDefinitions = $functionDefinitions
    }
    
    JeaSessionConfiguration DscEndpoint
    {
        Ensure = 'Present'
        DependsOn = '[JeaRoleCapabilities]ReadDiagnosticsRole'
        Name = 'DSC'
        RoleDefinitions = '@{ Everyone = @{ RoleCapabilities = "ReadDiagnosticsRole" } }'
        SessionType = 'RestrictedRemoteServer'
        ModulesToImport = 'PSDesiredStateConfiguration'
    }
}
