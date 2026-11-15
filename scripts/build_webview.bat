@echo off
rem Compile the webview C++ core into %OUT%\webview.o on Windows.
rem Invoked by sx.mod from inside lib\webview.
rem Set CXX=clang++ or CXX=cl to choose a compiler.
rem Set WEBVIEW2_INCLUDE to the WebView2 SDK include directory when it is
rem not already on the default include path.

setlocal enabledelayedexpansion

set OUT=%~1
if "%OUT%"=="" (
    echo build_webview.bat: missing output directory 1>&2
    exit /b 1
)

set ROOT=%~dp0..
set SRC=%ROOT%\lib\webview\core\src\webview.cc
set INC=%ROOT%\lib\webview\core\include
set WINDECOR=%ROOT%\src\formant\windecor_win.cc

if not exist "%SRC%" (
    echo build_webview.bat: webview sources not found at %SRC% 1>&2
    echo run "spectre restore" to fetch dependencies 1>&2
    exit /b 1
)

if not exist "%OUT%" mkdir "%OUT%"

if not "%WEBVIEW2_INCLUDE%"=="" (
    set WV2_INC=%WEBVIEW2_INCLUDE%
) else (
    set WV2_INC=
    if exist "%USERPROFILE%\.nuget\packages\microsoft.web.webview2" (
        for /d %%d in ("%USERPROFILE%\.nuget\packages\microsoft.web.webview2\*") do (
            if exist "%%d\build\native\include\WebView2.h" set WV2_INC=%%d\build\native\include
        )
    )
)

if defined CXX (
    set CXX_BIN=%CXX%
) else (
    where clang++ >nul 2>&1
    if !errorlevel!==0 (
        set CXX_BIN=clang++
    ) else (
        where cl >nul 2>&1
        if !errorlevel!==0 (
            set CXX_BIN=cl
        ) else (
            echo build_webview.bat: no C++ compiler found ^(set CXX^) 1>&2
            exit /b 1
        )
    )
)

if /i "%CXX_BIN%"=="cl" goto msvc

:clang
set WV2_FLAG=
if defined WV2_INC set WV2_FLAG=-I"%WV2_INC%"
clang++ -std=c++11 -O2 -DWEBVIEW_STATIC -I"%INC%" %WV2_FLAG% ^
    -c "%SRC%" -o "%OUT%\webview.o"
if errorlevel 1 exit /b 1
clang++ -std=c++11 -O2 ^
    -c "%WINDECOR%" -o "%OUT%\windecor.o"
if errorlevel 1 exit /b 1
echo built %OUT%\webview.o
echo built %OUT%\windecor.o
exit /b 0

:msvc
set WV2_FLAG=
if defined WV2_INC set WV2_FLAG=/I"%WV2_INC%"
cl /nologo /std:c++17 /O2 /EHsc /DWEBVIEW_STATIC /I"%INC%" %WV2_FLAG% ^
    /c "%SRC%" /Fo"%OUT%\webview.o"
if errorlevel 1 exit /b 1
cl /nologo /std:c++17 /O2 /EHsc ^
    /c "%WINDECOR%" /Fo"%OUT%\windecor.o"
if errorlevel 1 exit /b 1
echo built %OUT%\webview.o
echo built %OUT%\windecor.o
exit /b 0
