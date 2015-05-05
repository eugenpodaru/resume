@if "%SCM_TRACE_LEVEL%" NEQ "4" @echo off

:: ----------------------
:: KUDU Deployment Script
:: Version: 0.2.2
:: ----------------------

:: Prerequisites
:: -------------

:: Verify node.js installed
where node 2>nul >nul
IF %ERRORLEVEL% NEQ 0 (
  echo Missing node.js executable, please install node.js, if already installed make sure it can be reached from current environment.
  goto error
)

:: Setup
:: -----

setlocal enabledelayedexpansion

SET ARTIFACTS=%~dp0%..\artifacts

IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

IF NOT DEFINED DEPLOYMENT_TARGET (
  SET DEPLOYMENT_TARGET=%ARTIFACTS%\wwwroot
)

IF NOT DEFINED KUDU_SYNC_CMD (
  :: Install kudu sync
  echo Installing Kudu Sync
  call npm install kudusync -g --silent
  IF !ERRORLEVEL! NEQ 0 goto error

  :: Locally just running "kuduSync" would also work
  SET KUDU_SYNC_CMD=%appdata%\npm\kuduSync.cmd
)
IF NOT DEFINED DEPLOYMENT_TEMP (
  SET DEPLOYMENT_TEMP=%temp%\___deployTemp%random%
  SET CLEAN_LOCAL_DEPLOYMENT_TEMP=true
)

IF DEFINED CLEAN_LOCAL_DEPLOYMENT_TEMP (
  IF EXIST "%DEPLOYMENT_TEMP%" rd /s /q "%DEPLOYMENT_TEMP%"
  mkdir "%DEPLOYMENT_TEMP%"
)

::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::::
:: Deployment
:: ----------

:: Download the wget client
pushd "%DEPLOYMENT_SOURCE%\Resume"

echo Running wget grunt task...
call :ExecuteCmd grunt wget
IF !ERRORLEVEL! NEQ 0 goto error

popd

:: Clone the repository from GitHub
pushd "%DEPLOYMENT_TEMP%"

call :ExecuteCmd mkdir "%GITHUB_USERNAME%"
IF !ERRORLEVEL! NEQ 0 goto error
call :ExecuteCmd git clone --quiet --branch=master https://%GITHUB_USERNAME%:%GITHUB_ACCESS_TOKEN%@github.com/%GITHUB_USERNAME%/%GITHUB_USERNAME%.github.io.git .\%GITHUB_USERNAME%\
IF !ERRORLEVEL! NEQ 0 goto error
  
pushd "%GITHUB_USERNAME%"

:: Set git settings
call :ExecuteCmd git config user.email %GITHUB_EMAIL%
IF !ERRORLEVEL! NEQ 0 goto error
call :ExecuteCmd git config user.name %GITHUB_USERNAME%
IF !ERRORLEVEL! NEQ 0 goto error
call :ExecuteCmd git config push.default matching
IF !ERRORLEVEL! NEQ 0 goto error

popd
popd

goto end

:: Execute command routine that will echo out when error
:ExecuteCmd
setlocal
set _CMD_=%*
call %_CMD_%
if "%ERRORLEVEL%" NEQ "0" echo Failed exitCode=%ERRORLEVEL%, command=%_CMD_%
exit /b %ERRORLEVEL%

:error
endlocal
echo An error has occurred during web site deployment.
call :exitSetErrorLevel
call :exitFromFunction 2>nul

:exitSetErrorLevel
exit /b 1

:exitFromFunction
()

:end
endlocal
echo Finished successfully.
