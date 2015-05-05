# Functions
# -------------

# Write an error message and exit with a code
function Error(){
    Write-Host "An error has occurred during web site deployment.";
    Exit 1;
}

# Check the last exit code, and in case it's different than 0, exit with an error
function CheckLastExitCode(){
    if($LASTEXITCODE -ne 0){
        Error;
    }
}

# Create the directory. If it exists, delete it first
function CreateDirectory($dir){
    if(Test-Path -Path $dir){
        Remove-Item -Recurse -Force -Path $dir;
        CheckLastExitCode;
    }
    New-Item -Force -ItemType directory -Path $dir;
    CheckLastExitCode;
}

# Prerequisites
# -------------

# Verify node.js installed
if(-NOT [bool](Get-Command -Name "node" -ErrorAction SilentlyContinue)){
    Write-Host "Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.";
    Error;
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
    Write-Host "Installing Kudu Sync";
    & npm install kudusync -g --silent;
    CheckLastExitCode;
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
Write-Host "Restoring NuGet packages...";
& nuget restore "$DeploymentSource\Resume.sln";
CheckLastExitCode;

# 2. Install npm packages, bower, grunt, and bower packages
Push-Location "$DeploymentSource\Resume";

Write-Host "Installing npm packages...";
& npm install;
CheckLastExitCode;

Write-Host "Running npm dedupe...";
& npm dedupe;
CheckLastExitCode;

Write-Host "Installing grunt-cli...";
& npm install grunt-cli -g;
CheckLastExitCode;

Write-Host "Installing bower...";
& npm install bower -g;
CheckLastExitCode;

Write-Host "Running bower-install grunt task...";
& grunt bower-install;
CheckLastExitCode;

Pop-Location;

# 3. Build to the temporary path
Write-Host "Build the solution";
&$MSBuildPath "$DeploymentSource\Resume\Resume.csproj" /nologo /verbosity:m /t:Build /t:pipelinePreDeployCopyAllFilesToOneFolder /p:_PackageTempDir="$DeploymentTemp";AutoParameterizationWebConfigConnectionStrings=false;Configuration=Release /p:SolutionDir="$DeploymentSource\.\\" $ScmBuildArgs;
CheckLastExitCode;

# 4. KuduSync
Write-Host "KuduSync";
&$KuduSyncCmd -v 50 -f "$DeploymentTemp" -t "$DeploymentTarget" -n "$NextManifestPath" -p "$PreviousManifestPath" -i ".git;.hg;.deployment;deploy.cmd";
CheckLastExitCode;

# 5. Copy the post deployment scripts
Push-Location "$DeploymentSource";
Write-Host "Copy the post deployment scripts...";
& xcopy /I "$PostDeploymentSource" "$PostDeploymentTarget";
CheckLastExitCode;
Pop-Location;

# Post deployment stub
if(Test-Path Env:\POST_DEPLOYMENT_ACTION){
    Write-Host "Running the post deployment scripts...";
    &$env:POST_DEPLOYMENT_ACTION;
    CheckLastExitCode;
}

Write-Host "Finished successfully.";