param
(
    [Parameter()]
    [System.String]
    $BuiltModuleSubdirectory = (property BuiltModuleSubdirectory ''),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $VersionedOutputDirectory = (property VersionedOutputDirectory $true),

    [Parameter()]
    [System.String]
    $ProjectName = (property ProjectName ''),

    [Parameter()]
    [System.String]
    $SourcePath = (property SourcePath ''),

    [Parameter()]
    $ChangelogPath = (property ChangelogPath 'CHANGELOG.md'),

    [Parameter()]
    $ReleaseNotesPath = (property ReleaseNotesPath (Join-Path $OutputDirectory 'ReleaseNotes.md')),

    [Parameter()]
    [string]
    $PAT = (property PAT ''),

    [Parameter()]
    [string]
    $ReleaseBranch = (property ReleaseBranch 'main'),

    [Parameter()]
    [string]
    $GitHubConfigUserEmail = (property GitHubConfigUserEmail ''),

    [Parameter()]
    [string]
    $GitHubConfigUserName = (property GitHubConfigUserName ''),

    [Parameter()]
    $GitHubFilesToAdd = (property GitHubFilesToAdd ''),

    [Parameter()]
    $BuildInfo = (property BuildInfo @{ }),

    [Parameter()]
    $SkipPublish = (property SkipPublish ''),

    [Parameter()]
    $MainGitBranch = (property MainGitBranch 'main')
)

#TODO: Replace with https://github.com/dsccommunity/PSNativeCmdDevKit/search?q=Invoke-NativeCommand
function Invoke-Utility
{
    <#
    .SYNOPSIS
    Invokes an external utility, ensuring successful execution.

    .DESCRIPTION
    Invokes an external utility (program) and, if the utility indicates failure by
    way of a nonzero exit code, throws a script-terminating error.

    * Pass the command the way you would execute the command directly.
    * Do NOT use & as the first argument if the executable name is not a literal.

    .EXAMPLE
    Invoke-Utility git push

    Executes `git push` and throws a script-terminating error if the exit code
    is nonzero.
    #>
    $exe, $argsForExe = $Args
    # Workaround: Prevents 2> redirections applied to calls to this function
    #             from accidentally triggering a terminating error.
    #             See bug report at https://github.com/PowerShell/PowerShell/issues/4002

    $ErrorActionPreference = 'Continue'
    try
    {
        & $exe $argsForExe
    }
    catch
    {
        Throw
    } # catch is triggered ONLY if $exe can't be found, never for errors reported by $exe itself

    if ($LASTEXITCODE)
    {
        Throw "$exe indicated failure (exit code $LASTEXITCODE; full command: $Args)."
    }
}

task UpdateGitTag -if ($PAT) {

    . Set-SamplerTaskVariable

    foreach ($gitHubConfigKey in 'GitHubFilesToAdd', 'GitHubConfigUserName', 'GitHubConfigUserEmail', 'UpdateChangelogOnPrerelease')
    {
        if (-not (Get-Variable -Name $gitHubConfigKey -ValueOnly -ErrorAction SilentlyContinue))
        {
            # Variable is not set in context, use $BuildInfo.GitHubConfig.<varName>
            $configValue = $BuildInfo.GitHubConfig.($gitHubConfigKey)
            Set-Variable -Name $gitHubConfigKey -Value $configValue
            Write-Build DarkGray "`t...Set $gitHubConfigKey to '$configValue'"
        }
    }
    Invoke-Utility git config user.name $GitHubConfigUserName
    Invoke-Utility git config user.email $GitHubConfigUserEmail

    try
    {
        Write-Build DarkGray "Setting 'extraheader Authorization: Basic' and using the personal access token"
        $patBase64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f 'PAT', $PAT)))
        Invoke-Utility git config http.extraheader "Authorization: Basic $patBase64"
        Invoke-Utility git config http.sslVerify false

        $env:GCM_PROVIDER = 'generic'
        Write-Build DarkGray "Calling 'git fetch --all --tags'"
        Invoke-Utility git fetch --all --tags | Out-Null

        $currentBranch = Invoke-Utility git branch --format='%(refname:short)'
        Write-Build DarkGray "Current branch is '$currentBranch'"
        if ($currentBranch -ne $MainGitBranch)
        {
            Write-Build DarkGray "Switching branch to '$MainGitBranch'"
            git checkout $MainGitBranch | Out-Null
        }

        $allTags = Invoke-Utility git tag
        $currentBranchTag = try
        {
            Write-Build DarkGray "Fetching tags: 'git describe --tags'"
            Invoke-Utility git describe --tags
        }
        catch
        {
            Write-Build Yellow "`t...No tags to read."
        }

        Write-Build DarkGray "Setting 'pull.rebase true'"
        Invoke-Utility git config pull.rebase true
        Write-Build DarkGray "Pulling tags from branch '$MainGitBranch'"
        Invoke-Utility git pull origin $MainGitBranch --tag | Out-Null

        $releaseTag = "v$ModuleVersion"
        Write-Build DarkGray "Release tag is '$releaseTag'"
        if ($currentBranchTag -ne $releaseTag -and $allTags -notcontains $releaseTag)
        {
            Write-Build DarkGray "Writing tag: 'git tag $releaseTag'"
            Invoke-Utility git tag $releaseTag
        }
        else
        {
            Write-Error -Message "The tag '$releaseTag' does already exist"
            return
        }

        # Look at the tags on latest commit for origin/$MainGitBranch (assume we're on detached head)
        Write-Build DarkGray "git rev-parse origin/$MainGitBranch"
        $mainHeadCommit = git 'rev-parse' "origin/$MainGitBranch"

        Write-Build DarkGray "git tag -l --points-at $mainHeadCommit"
        $tagsAtCurrentPoint = git tag -l --points-at $mainHeadCommit

        Write-Build DarkGray ($tagsAtCurrentPoint -join '|')

        Write-Build DarkGray "Pushing tag: 'git push origin --tags'"
        Invoke-Utility git push origin --tags
    }
    catch
    {
        Write-Error "Error pushing tag $ModuleVersion.`r`n $_"
    }
    finally
    {
        Invoke-Utility git config --unset http.extraheader
        Invoke-Utility git config --unset http.sslVerify
    }
}

task CreateChangelogReleaseOutput -if ($PAT) {

    . Set-SamplerTaskVariable

    foreach ($gitHubConfigKey in 'GitHubFilesToAdd', 'GitHubConfigUserName', 'GitHubConfigUserEmail', 'UpdateChangelogOnPrerelease')
    {
        if (-not (Get-Variable -Name $gitHubConfigKey -ValueOnly -ErrorAction SilentlyContinue))
        {
            # Variable is not set in context, use $BuildInfo.GitHubConfig.<varName>
            $configValue = $BuildInfo.GitHubConfig.($gitHubConfigKey)
            Set-Variable -Name $gitHubConfigKey -Value $configValue
            Write-Build DarkGray "`t...Set $gitHubConfigKey to '$configValue'"
        }
    }
    Invoke-Utility git config user.name $GitHubConfigUserName
    Invoke-Utility git config user.email $GitHubConfigUserEmail

    $changelogPath = Get-SamplerAbsolutePath -Path $ChangeLogPath -RelativeTo $ProjectPath
    Write-Build DarkGray "`Changelog Path '$changeLogPath'"

    try
    {
        $patBase64 = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(('{0}:{1}' -f 'PAT', $PAT)))
        Invoke-Utility git config http.extraheader "Authorization: Basic $patBase64"
        Invoke-Utility git config http.sslVerify false

        $currentBranch = Invoke-Utility git branch --format='%(refname:short)'
        if ($currentBranch -ne $MainGitBranch)
        {
            Invoke-Utility git checkout $MainGitBranch | Out-Null
        }
        Invoke-Utility git config pull.rebase true
        Invoke-Utility git pull origin $MainGitBranch --tag

        $mainHeadCommit = Invoke-Utility git log -n 1 --pretty=format:"%H"
        Write-Build DarkGray "git tag -l --points-at $mainHeadCommit"
        $tagsAtCurrentPoint = Invoke-Utility git tag -l --points-at $mainHeadCommit
        Write-Build DarkGray ($tagsAtCurrentPoint -join '|')

        # Only Update changelog if last commit is a full release
        if ($UpdateChangelogOnPrerelease)
        {
            $tagVersion = [string]($tagsAtCurrentPoint | Select-Object -First 1)
            Write-Build Green "Updating Changelog for PRE-Release '$tagVersion'"
        }
        elseif ($TagVersion = [string]($tagsAtCurrentPoint.Where{ $_ -notMatch 'v.*\-' }))
        {
            Write-Build Green "Updating the ChangeLog for release '$tagVersion'"
        }
        else
        {
            Write-Build Yellow "No Release Tag found to update the ChangeLog from in '$tagsAtCurrentPoint'"
            return
        }
    }
    catch
    {
        Write-Error "Error updating changelog and generating release information: $($_.Exception.Message)"
    }

    try
    {
        Write-Build DarkGray 'Updating Changelog file'
        Update-Changelog -ReleaseVersion ($TagVersion -replace '^v') -LinkMode None -Path $ChangelogPath -ErrorAction SilentlyContinue
        Invoke-Utility git add $GitHubFilesToAdd
        Invoke-Utility git commit -m "Updating ChangeLog since $tagVersion +semver:skip"

        Invoke-Utility git push

        Write-Build Green 'Changelog changes pushed'
    }
    catch
    {
        Write-Build Red "Error pushing the changelog: $_"
    }
}
