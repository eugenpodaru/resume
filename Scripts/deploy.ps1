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

$MSBuildPath = "$env:windir\Microsoft.NET\Framework\v4.0.30319\msbuild.exe";
if(Test-Path Env:\MSBUILD_PATH){
    $MSBuildPath = $env:MSBUILD_PATH;
}

$ScmBuildArgs = "";
if(Test-Path Env:\SCM_BUILD_ARGS){
    $ScmBuildArgs = $env:SCM_BUILD_ARGS;
}

$PostDeploymentSource = "$DeploymentSource\Scripts\PostDeploymentActions";
$PostDeploymentTarget = "$DeploymentSource\..\deployments\tools\PostDeploymentActions";

CreateDirectory $PostDeploymentTarget;

# Deployment
# -------------

# 1. Restore NuGet packages
Write-Output "Restoring NuGet packages...";
& nuget restore "$DeploymentSource\Resume.sln";
CheckLastExitCode "Could not restore NuGet packages";

# 2. Install npm packages, bower, grunt, and bower packages
Push-Location "$DeploymentSource\Resume";

Write-Output "Installing npm packages...";
& npm install;
CheckLastExitCode "Installing npm packages failed";

Write-Output "Running npm dedupe...";
& npm dedupe;
CheckLastExitCode "Running npm dedupe failed";

Write-Output "Installing grunt-cli...";
& npm install grunt-cli -g;
CheckLastExitCode "Installing grunt-cli failed";

Write-Output "Installing bower...";
& npm install bower -g;
CheckLastExitCode "Installing bower failed";

Write-Output "Running bower-install grunt task...";
& grunt bower-install;
CheckLastExitCode "Running bower-install task failed";

Pop-Location;

# 3. Build to the temporary path
Write-Output "Build the solution";
&$MSBuildPath "$DeploymentSource\Resume\Resume.csproj" /nologo /verbosity:m /t:Build /t:pipelinePreDeployCopyAllFilesToOneFolder /p:_PackageTempDir="$DeploymentTemp";AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release /p:SolutionDir="$DeploymentSource\.\\" $ScmBuildArgs;
CheckLastExitCode "Build failed.";

# 4. KuduSync
Write-Output "KuduSync";
&$KuduSyncCmd -v 50 -f "$DeploymentTemp" -t "$DeploymentTarget" -n "$NextManifestPath" -p "$PreviousManifestPath" -i ".git;.hg;.deployment;deploy.cmd";
CheckLastExitCode "KuduSync failed";

# 5. Copy the post deployment scripts
Push-Location "$DeploymentSource";
Write-Output "Copy the post deployment scripts...";
& xcopy /I "$PostDeploymentSource" "$PostDeploymentTarget";
CheckLastExitCode "Copying the post deployment scripts failed";
Pop-Location;

# Post deployment stub
if(Test-Path Env:\POST_DEPLOYMENT_ACTION){
    Write-Output "Running the post deployment scripts...";
    &$env:POST_DEPLOYMENT_ACTION;
    CheckLastExitCode "Running the post deployment scripts failed";
}

Write-Output "Finished successfully.";