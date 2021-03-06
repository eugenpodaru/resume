# Functions
# -------------

# Write an error message and exit with a code
function Error($msg){
    Write-Output "An error has occurred during web site deployment.";
    Write-Output $msg;
    Exit 1;
}

# Check the last exit code, and in case it's different than 0, exit with an error
function CheckLastExitCode($msg){
    if($LASTEXITCODE -ne 0){
        Error $msg;
    }
}

# Create the directory. If it exists, delete it first
function CreateDirectory($dir){
    if(Test-Path -Path $dir){
        Remove-Item -Recurse -Force -Path $dir | Out-Null;
    }
    New-Item -Force -ItemType directory -Path $dir  | Out-Null;
}

# Prerequisites
# -------------

# Verify node.js installed
if(-NOT [bool](Get-Command -Name "node" -ErrorAction SilentlyContinue)){
    Error "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.";
}

# get the paths from the environment variables
$Artifacts = "$PSScriptRoot\..\artifacts";

$DeploymentSource = $PSScriptRoot;
if(Test-Path Env:\DEPLOYMENT_SOURCE){
    $DeploymentSource = $env:DEPLOYMENT_SOURCE;
}

$DeploymentTarget = "$Artifacts\wwwroot";
if(Test-Path Env:\DEPLOYMENT_TARGET){
    $DeploymentTarget = $env:DEPLOYMENT_TARGET;
}

$NextManifestPath = "$Artifacts\manifest";
if(Test-Path Env:\NEXT_MANIFEST_PATH){
    $NextManifestPath = $env:NEXT_MANIFEST_PATH;
}

$PreviousManifestPath = "$Artifacts\manifest";
if(Test-Path Env:\PREVIOUS_MANIFEST_PATH){
    $PreviousManifestPath = $env:PREVIOUS_MANIFEST_PATH;
}

$KuduSyncCmd = "$env:APPDATA\npm\kuduSync.cmd";
if(Test-Path Env:\KUDU_SYNC_CMD){
    $KuduSyncCmd = $env:KUDU_SYNC_CMD;
} else {
    Write-Output "Installing Kudu Sync";
    & npm install kudusync -g --silent;
    CheckLastExitCode "Could not install KuduSync";
}

$DeploymentTemp = "$env:TEMP\__deployTemp" + (Get-Random);
if(Test-Path Env:\DEPLOYMENT_TEMP){
    $DeploymentTemp = $env:DEPLOYMENT_TEMP;
} else {
    CreateDirectory $DeploymentTemp;
}

$PostDeploymentTemp = "$env:TEMP\__postDeployTemp" + (Get-Random);
CreateDirectory $PostDeploymentTemp;

$MSBuildPath = "$env:PROGRAMFILES(X86)\MSBuild\14.0\Bin\msbuild.exe";
if(Test-Path Env:\MSBUILD_PATH){
    $MSBuildPath = $env:MSBUILD_PATH;
}

$ScmBuildArgs = "";
if(Test-Path Env:\SCM_BUILD_ARGS){
    $ScmBuildArgs = $env:SCM_BUILD_ARGS;
}

$GitHubUsername = "";
if(Test-Path Env:\GITHUB_USERNAME){
    $GitHubUsername = $env:GITHUB_USERNAME;
}

$GitHubEmail = "";
if(Test-Path Env:\GITHUB_EMAIL){
    $GitHubEmail = $env:GITHUB_EMAIL;
}

$GitHubAccessToken = "";
if(Test-Path Env:\GITHUB_ACCESS_TOKEN){
    $GitHubAccessToken = $env:GITHUB_ACCESS_TOKEN;
}

# Deployment
# -------------

# 1. Restore NuGet packages
Write-Output "Restoring NuGet packages...";
& nuget restore "$DeploymentSource\Resume.sln";
CheckLastExitCode "Could not restore NuGet packages";

# 2. Install npm packages, bower, gulp and tsd
Push-Location "$DeploymentSource\Resume";

Write-Output "Installing npm packages...";
& npm install;
CheckLastExitCode "Installing npm packages failed";

Write-Output "Pruning npm packages...";
& npm prune;
CheckLastExitCode "Pruning npm packages failed";

Write-Output "Running npm dedupe...";
& npm dedupe;
CheckLastExitCode "Running npm dedupe failed";

Write-Output "Installing rimraf...";
& npm install rimraf -g;
CheckLastExitCode "Installing rimraf failed";

Write-Output "Installing bower...";
& npm install bower -g;
CheckLastExitCode "Installing bower failed";

Write-Output "Installing tsd...";
& npm install tsd -g;
CheckLastExitCode "Installing tsd failed";

Write-Output "Installing gulp...";
& npm install gulp-cli -g;
CheckLastExitCode "Installing gulp failed";

Write-Output "Running tsd update...";
& tsd update -o -s;
CheckLastExitCode "Running tsd update failed";

Pop-Location;

# 3. Run the before-build gulp task
Push-Location "$DeploymentSource\Resume";
Write-Output "Running gulp before-build task...";
& gulp before-build;
CheckLastExitCode "Running gulp before-build task failed";
Pop-Location;

# 4. Build to the temporary path
Write-Output "Build the solution";
&$MSBuildPath "$DeploymentSource\Resume\Resume.csproj" /nologo /verbosity:m /t:Build /t:pipelinePreDeployCopyAllFilesToOneFolder /p:_PackageTempDir="$DeploymentTemp" /p:AutoParameterizationWebConfigConnectionStrings=false /p:Configuration=Release /p:SolutionDir="$DeploymentSource\.\\" $ScmBuildArgs;
CheckLastExitCode "Build failed.";

# 5. Run the after-build gulp task
Push-Location "$DeploymentTemp";

Write-Output "Installing npm packages...";
& npm install;
CheckLastExitCode "Installing npm packages failed";

Write-Output "Pruning npm packages...";
& npm prune;
CheckLastExitCode "Pruning npm packages failed";

Write-Output "Running npm dedupe...";
& npm dedupe;
CheckLastExitCode "Running npm dedupe failed";

Write-Output "Running gulp after-build task...";
& gulp after-build;
CheckLastExitCode "Running gulp after-build task failed";

Write-Output "Removing the node_modules directory";
& rimraf node_modules
CheckLastExitCode "Removing the node_modules directory failed";

Pop-Location;

# 6. KuduSync
Write-Output "KuduSync";
&$KuduSyncCmd -v 50 -f "$DeploymentTemp" -t "$DeploymentTarget" -n "$NextManifestPath" -p "$PreviousManifestPath" -i ".git;.hg;.deployment;deploy.cmd";
CheckLastExitCode "KuduSync failed";

# PostDeployment
# -------------

# 7. Mirror the site using wget
Push-Location "$PostDeploymentTemp";
Write-Output "Mirroring the site using wget...";
& "$DeploymentSource\Resume\bin\wget.exe" --recursive --html-extension --no-host-directories --directory-prefix=static-site http://${GitHubUsername}.azurewebsites.net -o wget.log;
& cat wget.log;
Pop-Location;

# 8. Clone the repository from GitHub
Push-Location "$PostDeploymentTemp";
Write-Output "Clonning the repository from GitHub...";
CreateDirectory "$GitHubUsername";
& git clone --branch=master https://${GitHubUsername}:$GitHubAccessToken@github.com/$GitHubUsername/$GitHubUsername.github.io.git .\$GitHubUsername\;
Push-Location "$GitHubUsername";
& git status;
Pop-Location;
Pop-Location;

# 9. Set git settings
Push-Location "$PostDeploymentTemp\$GitHubUsername";
Write-Output "Setting git settings...";
& git config user.email $GitHubEmail;
& git config user.name $GitHubUsername;
& git config push.default matching;
Pop-Location;

# 10. Empty the contents of the git repository
Push-Location "$PostDeploymentTemp\$GitHubUsername";
Write-Output "Cleaning the git repository...";
Get-ChildItem -Attributes !r | Remove-Item -Recurse -Force;
Pop-Location;

# 11. Copy the contents of the static site to the repository
Push-Location "$PostDeploymentTemp";
Write-Output "Copying the contents of the static site to the repository";
Copy-Item -path "static-site\*" -Destination "$GitHubUsername" -Recurse -Force;
Pop-Location;

# 12. Push the changes to GitHub
Push-Location "$PostDeploymentTemp\$GitHubUsername";
Write-Output "Pushing the changes to GitHub...";
& git status;
$thereAreChanges = git status | select-string -pattern "Changes not staged for commit:","Untracked files:" -simplematch;
if ($thereAreChanges -ne $null) { 
    Write-Output "Committing changes to site...";
    & git add --all;
    & git status;
    & git commit -m "static site regeneration";
    & git status;
    Write-Output "Pushing the changes to GitHub...";
    & git push --quiet;
    Write-Output "Pushed to GitHub";
} 
else { 
    Write-Output "No changes to documentation to commit"
}
Pop-Location;

Write-Output "Finished successfully.";