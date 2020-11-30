@echo off

set DIR=%~dp0

..\tool\CfgExportor.exe %1 %DIR%\..\system\

set NAME=%1
set CFGNAME=

:next

if "%NAME:~-1%" == " " (
set NAME=%NAME:~0,-1%
goto next
)

if not "%NAME:~-1%" == "\" (
set CFGNAME=%NAME:~-1%%CFGNAME%
set NAME=%NAME:~0,-1%
goto next
)

copy "%DIR%..\system\%CFGNAME:~0,-4%config" "%DIR%..\..\..\system\*"

pause
