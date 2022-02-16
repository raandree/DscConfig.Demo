@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    'powershell-yaml'            = 'latest'
    InvokeBuild                  = 'latest'
    PSScriptAnalyzer             = 'latest'
    Pester                       = '4.10.1'
    Plaster                      = 'latest'
    ModuleBuilder                = 'latest'
    ChangelogManagement          = 'latest'
    Sampler                      = 'latest'
    'Sampler.GitHubTasks'        = 'latest'
    Datum                        = '0.39.0'
    'Datum.ProtectedData'        = '0.0.1'
    DscBuildHelpers              = '0.0.42'
    'DscResource.Test'           = 'latest'
    MarkdownLinkCheck            = 'latest'
    'DscResource.AnalyzerRules'  = 'latest'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '8.5.0'
    NetworkingDsc                = '8.2.0'
    JeaDsc                       = '0.7.2'
    xWebAdministration           = '3.2.0'
    FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'

}
