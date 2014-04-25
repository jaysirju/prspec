@ECHO OFF
REM the below will run forever
:loop
@IF NOT DEFINED SESSIONNAME (@SET SESSIONNAME=Console)
@SETLOCAL
@SET EXITCODE=0
@SET instance=%DATE% %TIME% %RANDOM%
@TITLE %instance%

@FOR /F "usebackq tokens=1,2" %%a IN (`tasklist /FO list /FI "SESSIONNAME eq %SESSIONNAME%" /FI "USERNAME eq %USERDOMAIN%\%USERNAME%" /FI "WINDOWTITLE eq %instance%" ^| FIND /I "PID:"`) DO @(
    @SET PID=%%b
)

@IF NOT DEFINED PID (
    @FOR /F "usebackq tokens=1,2" %%a IN (`tasklist /FO list /FI "SESSIONNAME eq %SESSIONNAME%" /FI "USERNAME eq %USERDOMAIN%\%USERNAME%" /FI "WINDOWTITLE eq Administrator:  %instance%" ^| FIND /I "PID:"`) DO @(
        @SET PID=%%b
    )
)

@IF NOT DEFINED PID (
    @ECHO ERROR: Could not determine the Process ID of the current script.
    @SET EXITCODE=1
) ELSE (
    @ECHO %PID% > never_ending.out
)

REM wait 1 second
ping -n 1 127.0.0.1 > NUL
GOTO loop