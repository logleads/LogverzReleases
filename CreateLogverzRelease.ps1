#determine os type AND verify dependencies are present 
if ($Env:OS -eq "Windows_NT"){
    $OSType="Windows"
    $gitcommand="git.exe"
    
    $cmdName="7z"
    if (!(Get-Command $cmdName -errorAction SilentlyContinue))
    {
        write-host "`n $cmdName dependency not installed, use chocolatey (https://chocolatey.org/), 'choco install 7zip' command for installation`n" -ForegroundColor yellow
        Start-Sleep -Seconds 10
        exit
    }
    write-host "`n Operating System Windows`n" -ForegroundColor green
}
else{
    $OSType="Linux"
    $cmdName="7za"
    $gitcommand="git"
    if (!(Get-Command $cmdName -errorAction SilentlyContinue))
    {
        write-host "`n $cmdName dependency not installed, use package manger of your os command for installation example sudo apt install p7zip or sudo yum install p7zip for ubuntu/centos respectively" -ForegroundColor yellow
        write-host " in case command fails add extra repositories sudo add-apt-repository universe && sudo apt update for ubuntu and sudo yum install epel-release for centos. Than try again." -ForegroundColor yellow
        Start-Sleep -Seconds 10
        exit
    }
    write-host "`n Operating System Linux`n" -ForegroundColor green

}

#constants
$ReleaseRepositoryName="LogverzReleases"
$projectpath=$env:RELEASEPROJECTPATH
#$projectpath="C:/Users/Administrator/Documents/LogverzReleases" # change accroding to local path
$componentpath=$projectpath+"/LogverzCore"
$buildrelativepath="ProjectBuild"
$buildfullpath="$projectpath/$buildrelativepath/build"
$portalrepobaseurl="https://logleads@dev.azure.com/logleads/LogverzPortal/_git/"
$corerepobaseurl="https://logleads@dev.azure.com/logleads/LogverzCore/_git/LogverzCore"

write-host "the build full path:" $buildfullpath
#validating environment
if (($(test-path $buildfullpath) -eq $false)){
    New-Item -Path $buildfullpath -ItemType "Directory" -Force
}


cd $projectpath
if (($(test-path $componentpath) -eq $false)){
    write-host "`n Core Project folder dependency missing, LogverzCore repo must be present, please clone LogverzCore into the Logverz Releases project folder`n" -ForegroundColor yellow
    Start-Sleep -Seconds 10
    exit
}

cd $componentpath
$gitremoteurl=iex "git config --get remote.origin.url"
if ($gitremoteurl  -ne $corerepobaseurl){
   write-host "`n Core Project incorrect reference, LogverzCore folder present but not referencing core project, please clone LogverzCore into the Logverz Releases project folder`n" -ForegroundColor yellow
   Start-Sleep -Seconds 10
   exit
}else{
   write-host "`n Environment is setup correctly`n" -ForegroundColor green
}


Import-Module $($projectpath+"/LogverzCore/infrastructure/tools/LogverzBuild.psm1") -Verbose:$false

$extrafiles= get-extrafiles -filepath $($componentpath+"/infrastructure/tools/buildextrafiles.csv")
$versions=Get-ChildItem $($projectpath+"/Versions") | Sort-Object CreationTime -Descending | select name,creationtime |Select -First 2
$latestversion=$($versions[0].Name).Replace(".json","").Replace("v","")
$buildparameters=Get-Content $($projectpath+"/Versions/v"+$latestversion+".json")|ConvertFrom-Json

$CoreTag=$buildparameters.Core.tag
$CoreBranchName=$buildparameters.Core.branch
$PortalTag=$buildparameters.Portal.tag
$PortalBranch=$buildparameters.Portal.branch
$PortalAccessTag=$buildparameters.PortalAccess.tag
$PortalAccessBranch=$buildparameters.PortalAccess.branch
$ReleaseTag=$latestversion

#First time only:
#Install-Module -Name PowerShellForGitHub
#[string]$userName = 'AnyUserName'
#[string]$userPassword = 'specify_GH_accesstoken'
#[securestring]$secStringPassword = ConvertTo-SecureString $userPassword -AsPlainText -Force
#[pscredential]$credObject = New-Object System.Management.Automation.PSCredential ($userName, $secStringPassword)
#Set-GitHubAuthentication -Credential $credObject 
#Validate that access works:
#Get-GitHubRepository -RepositoryName LogverzReleases -OwnerName logleads

Import-Module PowerShellForGitHub


build-webapp-source -builddirectory $buildfullpath -repositoryurl $($portalrepobaseurl+"Portal")`
                    -appname "Portal" -branchname $PortalBranch -OSType $OSType  -tag $PortalTag

build-webapp-source -builddirectory $buildfullpath -repositoryurl $($portalrepobaseurl+"PortalAccess")`
                    -appname "PortalAccess" -branchname $PortalAccessBranch -OSType $OSType  -tag $PortalAccessTag

set-init-sources -projectpath $projectpath -extrafiles $extrafiles -builddirectory $buildrelativepath -componentpath $componentpath `
                 -OSType $OSType -repositoryurl $corerepobaseurl -branchname $CoreBranchName -tag $CoreTag


#rename init.zip according to the releasetag. 
$newname=$("init_v"+$ReleaseTag+".zip")
Rename-Item -Path $($projectpath+"/"+$buildrelativepath+"/init.zip")  -NewName $newname
$AssetPath = $($projectpath+"/"+$buildrelativepath+"/"+$newname)
$ReleaseBody= $(Get-Content -Path $($projectpath+"/ReleaseNotes/v"+$ReleaseTag+".md") -Encoding UTF8 |Out-String)

create-GHRelease -RepositoryName $ReleaseRepositoryName -Tag $ReleaseTag -AssetPath $AssetPath -Body $ReleaseBody



#temp: 
#$RepositoryName=$ReleaseRepositoryName 
#$Tag=$ReleaseTag 
#$Body=$ReleaseBody

#test core
#$branchname=$CoreBranchName
#$repositoryurl=$corerepobaseurl
#$builddirectory=$buildrelativepath
#$tag=$CoreTag

#$builddirectory=$buildfullpath
#$repositoryurl=$($portalrepobaseurl+"Portal") 
#$appname="Portal"
#$branchname=$PortalBranch
#$tag="0.7.0"

<#
$CoreTag="0.7.0"
$CoreBranchName="main"
$PortalTag="0.7.0"
$PortalBranch="main"
$PortalAccessTag="0.7.0"
$PortalAccessBranch="main"
$ReleaseTag=0.7.0
#>