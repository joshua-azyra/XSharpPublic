SET ROOT=%~dp0
SET BINARIESDIR=%ROOT%..\XSharp\Binaries
SET TESTDIR=%ROOT%..\XSharp\Binaries\Tests
SET XSCOMPILER=%BINARIESDIR%\Release\Exes\xsc\net46\xsc.exe 
SET XSTESTPROJECT=%ROOT%xSharp Tests.viproj
SET XSRUNTIMEFOLDER=%ROOT%Runtime
SET XSCONFIG=Debug
SET XSFIXEDTESTS=TRUE
SET XSLOGFILE=%TESTDIR%\LogFixed.Log
SET INCLUDE=%ROOT%..\XSharp\Src\Common;%ROOT%Include
IF NOT EXIST %ROOT%Bin MKDIR %ROOT%Bin
IF NOT EXIST %ROOT%Bin\Debug MKDIR %ROOT%Bin\Debug
IF NOT EXIST %ROOT%Bin\Release MKDIR %ROOT%Bin\Release
COPY %XSRUNTIMEFOLDER%\*.* %ROOT%Bin\Debug
COPY %XSRUNTIMEFOLDER%\*.* %ROOT%Bin\Release
IF NOT EXIST %TESTDIR% MKDIR %TESTDIR%
%XSCOMPILER% Automated\CompilerTests.prg /vo2 /out:%TESTDIR%\CompilerTests.exe /nowarn:165,9101 
%TESTDIR%\CompilerTests.exe
SET XSFIXEDTESTS=False
SET XSLOGFILE=%TESTDIR%\LogBroken.Log
%TESTDIR%\CompilerTests.exe
