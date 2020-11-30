@echo off

set DIR=%~dp0
echo "%DIR%server"

del "%DIR%server\*"  /f /s /q
del "%DIR%client\*"  /f /s /q
del "%DIR%system\*"  /f /s /q

REM for %%i in (.\excel\*.xlsx) do ".\tool\CfgExportor.exe" %DIR%server\ %DIR%client\ %%i %DIR%csv\

for %%i in (.\excel\*.xlsx) do ".\tool\CfgExportor.exe" %%i %DIR%server\ %DIR%client\ 

copy "%DIR%server\*" "%DIR%..\..\cfg\*"

for %%i in (.\system_excel\*.xlsx) do ".\tool\CfgExportor.exe" %%i %DIR%system\

copy "%DIR%system\*" "%DIR%..\..\system\*"

pause
