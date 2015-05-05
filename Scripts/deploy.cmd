IF NOT DEFINED DEPLOYMENT_SOURCE (
  SET DEPLOYMENT_SOURCE=%~dp0%.
)

powershell -noexit -file "%DEPLOYMENT_SOURCE%\Scripts\deploy.ps1"