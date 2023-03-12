@{
    PSDependOptions              = @{
        AddToPath  = $true
        Target     = 'output\RequiredModules'
        Parameters = @{
            Repository      = 'PSGallery'
            AllowPreRelease = $true
        }
    }

    InvokeBuild                  = 'latest'
    PSScriptAnalyzer             = 'latest'
    Pester                       = 'latest'
    Plaster                      = 'latest'
    ModuleBuilder                = 'latest'
    ChangelogManagement          = 'latest'
    Sampler                      = 'latest'
    'Sampler.GitHubTasks'        = 'latest'
    'Sampler.AzureDevOpsTasks'   = 'latest'
    Datum                        = 'latest'
    'Datum.ProtectedData'        = 'latest'
    DscBuildHelpers              = 'latest'
    'DscResource.Test'           = 'latest'
    MarkdownLinkCheck            = 'latest'
    'DscResource.AnalyzerRules'  = 'latest'
    'DscResource.DocGenerator'   = 'latest'

    #DSC Resources
    xPSDesiredStateConfiguration = '9.1.0'
    ComputerManagementDsc        = '9.0.0'
    NetworkingDsc                = '9.0.0'
    JeaDsc                       = '0.7.2'
    WebAdministrationDsc         = '4.1.0'
    FileSystemDsc                = '1.1.1'
    SecurityPolicyDsc            = '2.10.0.0'

}
