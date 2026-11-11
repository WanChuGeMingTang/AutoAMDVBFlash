@ECHO OFF
REM Pure ASCII build - runs on any Windows code page, no language pack required.
SETLOCAL EnableExtensions DisableDelayedExpansion

REM ===========================================================================
REM  AutoAMDVBFlash
REM  Made by WanChuGeMingTang - the warmer guide to retro digital fun
REM ---------------------------------------------------------------------------
REM  Save  : backs up the VBIOS of GPU 0 into .\vbios_backups\
REM  Flash : drop a .rom file from ANY folder onto this .bat - the VBIOS is
REM          backed up first and the dropped image is force-flashed after it.
REM
REM  How it works:
REM    * no hard-coded flasher: every amdvbflash*.exe in  .\  ,  .\Software
REM      or  ..\Software  is accepted - the script folder is checked first,
REM      then the two Software folders; inside the folder that wins, the
REM      highest version in the file name is used;
REM    * pin one specific flasher with flasher.txt (run Choose-Flasher.bat or
REM      Choose-Flasher.bat) - handy for the modded "rescue" builds;
REM    * the folder may be renamed or moved anywhere (spaces, parentheses and
REM      non-ASCII characters included): all paths are relative and the UAC
REM      relaunch is done by a self-generated helper, no shortcut needed;
REM    * flasher output is captured to vbios_backups\flasher_out.log, so no
REM      flasher command line is ever built inside FOR /F.
REM
REM  Optional switches:
REM    --no-driver        do not load/remove the AmdTools driver
REM    --selftest         show what would be used, change nothing
REM    --list-flashers    print the detected flasher paths
REM    --choose-flasher   interactive flasher picker (writes flasher.txt)
REM                       text language: set NAVI_LANG=zh or en before calling
REM ===========================================================================


SET "SELF=%~f0"
SET "HERE=%~dp0"
SET "PIN_FILE=%HERE%flasher.txt"
SET "ELEVATED_HELPER=%TEMP%\AutoAMDVBFlash_elevated.cmd"

SET "MODE="
SET "ROM="
SET "SKIP_DRIVER="

REM ------------------------------------------------------------------ arguments
:args
IF "%~1"=="" GOTO :args_done
IF /I "%~1"=="--elevate-done"   GOTO :arg_elevated
IF /I "%~1"=="--selftest"       GOTO :arg_selftest
IF /I "%~1"=="--list-flashers"  GOTO :arg_list
IF /I "%~1"=="--choose-flasher" GOTO :arg_choose
IF /I "%~1"=="--no-driver"      GOTO :arg_nodriver
SET "ROM=%~1"
SHIFT
GOTO :args

:arg_elevated
SET "MODE=elevated"
SHIFT
GOTO :args

:arg_selftest
SET "MODE=selftest"
SHIFT
GOTO :args

:arg_list
SET "MODE=list"
SHIFT
GOTO :args

:arg_choose
SET "MODE=choose"
SHIFT
GOTO :args

:arg_nodriver
SET "SKIP_DRIVER=1"
SHIFT
GOTO :args

:args_done
IF /I "%MODE%"=="list"     GOTO :do_list
IF /I "%MODE%"=="selftest" GOTO :do_selftest
IF /I "%MODE%"=="choose"   GOTO :do_choose
IF /I "%MODE%"=="elevated" GOTO :main

REM ===========================================================================
REM  Not elevated yet: build the elevation helper and start it through UAC.
REM  AutoAMDVBFlash generates a small helper .cmd on the fly and starts it
REM  through UAC, so no shortcut file is needed and any location works. The
REM  needed values are passed to it as environment variables.
REM ===========================================================================
:elevate
SET "NAVI_SELF=%SELF%"
SET "NAVI_ROM=%ROM%"
SET "NAVI_HELPER=%ELEVATED_HELPER%"

> "%ELEVATED_HELPER%"  ECHO @ECHO OFF
>>"%ELEVATED_HELPER%"  ECHO SETLOCAL
>>"%ELEVATED_HELPER%"  ECHO CHCP 936 ^>NUL 2^>^&1
>>"%ELEVATED_HELPER%"  ECHO TITLE AutoAMDVBFlash
>>"%ELEVATED_HELPER%"  ECHO CALL "%NAVI_SELF%" --elevate-done
>>"%ELEVATED_HELPER%"  ECHO ECHO.
>>"%ELEVATED_HELPER%"  ECHO ECHO ...window can be closed by pressing any key
>>"%ELEVATED_HELPER%"  ECHO PAUSE ^>NUL

IF NOT EXIST "%ELEVATED_HELPER%" GOTO :elevate_failed

WHERE powershell >NUL 2>&1
IF ERRORLEVEL 1 GOTO :elevate_vbs

powershell -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; Start-Process -FilePath $env:NAVI_HELPER -Verb RunAs -WindowStyle Maximized" >NUL 2>&1
IF ERRORLEVEL 1 GOTO :elevate_failed
EXIT /B 0

:elevate_vbs
SET "NAVI_VBS=%TEMP%\AutoAMDVBFlash_elevated.vbs"
> "%NAVI_VBS%" ECHO CreateObject("Shell.Application").ShellExecute "%ELEVATED_HELPER%", "", "", "runas", 1
wscript //nologo "%NAVI_VBS%"
IF ERRORLEVEL 1 GOTO :elevate_failed
EXIT /B 0

:elevate_failed
ECHO.
ECHO ERROR: could not open the elevated window - nothing was done.
ECHO   * run this file again and confirm the UAC prompt, or
ECHO   * create a shortcut to this file, tick "Run as administrator" in the
ECHO     shortcut properties and drop .rom files onto that shortcut.
ECHO.
PAUSE
EXIT /B 1

REM ===========================================================================
REM  Elevated main flow
REM ===========================================================================
:main
PUSHD "%HERE%" >NUL 2>&1
IF ERRORLEVEL 1 GOTO :main_nofolder
TITLE AutoAMDVBFlash
IF NOT DEFINED ROM IF DEFINED NAVI_ROM SET "ROM=%NAVI_ROM%"

FLTMC >NUL 2>&1
IF ERRORLEVEL 1 GOTO :main_noadmin

CALL :choose_texts
ECHO.
CALL :print_credit
ECHO.

CALL :resolve_flasher
IF ERRORLEVEL 1 GOTO :main_noflasher

ECHO Flasher : %FLASHER_NAME%
ECHO Location: "%FLASHER%"
IF %FLASHER_COUNT% LEQ 1 GOTO :main_banner_done
ECHO.
ECHO Other versions found - pin one with Choose-Flasher.bat:
FOR %%F IN ("%FLASHER_DIR%\amdvbflash*.exe") DO IF EXIST "%%~fF" ECHO    - %%~nxF
:main_banner_done
ECHO.

IF DEFINED SKIP_DRIVER GOTO :driver_ready
IF NOT EXIST "driver\admin_load_driver.bat" GOTO :main_nodriver
CALL driver\admin_load_driver.bat
IF ERRORLEVEL 1 CALL driver\admin_remove_driver.bat
:driver_ready

IF EXIST "%ProgramData%\AMDTools\Config\AMDPlatToolsConfig.xml" GOTO :cfg_ready
MKDIR "%ProgramData%\AMDTools\Config" >NUL 2>&1
COPY /Y "driver\default-AMDPlatToolsConfig.xml" "%ProgramData%\AMDTools\Config\AMDPlatToolsConfig.xml" >NUL 2>&1
:cfg_ready

"%FLASHER%" --accept-EULA -i
CALL :run_save
IF ERRORLEVEL 1 GOTO :dispatch_done
IF "%ROM%"=="" GOTO :dispatch_saved
IF EXIST "%ROM%" GOTO :dispatch_flash
ECHO ERROR: vbios file "%ROM%" not found - nothing was flashed
GOTO :dispatch_done

:dispatch_saved
ECHO OK: VBIOS %AMD_VBIOS_SAVED_INFO%
GOTO :dispatch_done

:dispatch_flash
SET "AMD_VBIOS_TO_FLASH=%ROM%"
CALL :run_flash

:dispatch_done
IF NOT DEFINED SKIP_DRIVER CALL driver\admin_remove_driver.bat
POPD
EXIT /B 0

:main_nofolder
ECHO ERROR: cannot enter the script folder "%HERE%" - nothing was done.
EXIT /B 1

:main_noadmin
ECHO ERROR: administrator rights are required - nothing was done.
POPD
EXIT /B 1

:main_noflasher
ECHO.
ECHO ERROR: no amdvbflash*.exe found - nothing was done.
ECHO Put the flasher into one of these folders and name it amdvbflash*.exe
ECHO     "%HERE%"              (checked first)
ECHO     "%HERE%Software"
ECHO     "%HERE%..\Software"
ECHO Only the first folder that contains a flasher is used.
POPD
EXIT /B 1

:main_nodriver
ECHO ERROR: the "driver" folder is missing next to this script - nothing was done.
POPD
EXIT /B 1

REM ===========================================================================
REM  Subroutines
REM ===========================================================================

REM ------------------------------------------------------------- flasher lookup
REM  A flasher "version key" is built from the digits of the file name:
REM      amdvbflash.exe                  -> V0000
REM      amdvbflash5.0.638.exe           -> V000500000638
REM      amdvbflash_879_Moded_v1.exe     -> V08790001
REM      amdvbflash_879_Moded_v2.1.exe   -> V087900020001
REM  The keys are compared as strings, so the highest version wins.
:resolve_flasher
SET "FLASHER="
SET "FLASHER_NAME="
SET "FLASHER_DIR="
SET "FLASHER_PIN="
SET "FLASHER_COUNT=0"

IF DEFINED AUTO_PICK_ONLY GOTO :rf_scan
IF NOT EXIST "%PIN_FILE%" GOTO :rf_scan
FOR /F "usebackq delims=" %%L IN ("%PIN_FILE%") DO IF NOT DEFINED FLASHER_PIN IF NOT "%%L"=="" SET "FLASHER_PIN=%%~L"
IF NOT DEFINED FLASHER_PIN GOTO :rf_scan
CALL :find_pinned "%HERE%"
CALL :find_pinned "%HERE%Software"
CALL :find_pinned "%HERE%..\Software"
IF NOT DEFINED FLASHER GOTO :rf_scan
GOTO :rf_done

:rf_scan
CALL :scan_flasher_dir "%HERE%"
IF DEFINED FLASHER GOTO :rf_done
CALL :scan_flasher_dir "%HERE%Software"
IF DEFINED FLASHER GOTO :rf_done
CALL :scan_flasher_dir "%HERE%..\Software"
IF DEFINED FLASHER GOTO :rf_done
EXIT /B 1

:rf_done
IF NOT DEFINED FLASHER EXIT /B 1
FOR %%F IN ("%FLASHER%") DO SET "FLASHER_NAME=%%~nxF"
EXIT /B 0

:find_pinned
IF DEFINED FLASHER EXIT /B 0
FOR %%F IN ("%~1\amdvbflash*.exe") DO IF EXIST "%%~fF" IF /I "%%~nxF"=="%FLASHER_PIN%" SET "FLASHER=%%~fF"
IF NOT DEFINED FLASHER EXIT /B 0
SET "FLASHER_DIR=%~1"
SET "FLASHER_COUNT=0"
FOR %%F IN ("%~1\amdvbflash*.exe") DO IF EXIST "%%~fF" SET /A FLASHER_COUNT+=1
EXIT /B 0

:scan_flasher_dir
SET "SCAN_DIR=%~1"
SET "SCAN_BEST="
SET "SCAN_BESTKEY="
SET "SCAN_COUNT=0"
IF NOT EXIST "%SCAN_DIR%." EXIT /B 0
FOR %%F IN ("%SCAN_DIR%\amdvbflash*.exe") DO IF EXIST "%%~fF" CALL :flasher_candidate "%%~fF"
IF NOT DEFINED SCAN_BEST EXIT /B 0
SET "FLASHER=%SCAN_BEST%"
SET "FLASHER_DIR=%SCAN_DIR%"
SET "FLASHER_COUNT=%SCAN_COUNT%"
EXIT /B 0

:flasher_candidate
SET /A SCAN_COUNT+=1
SET "KEYACC="
FOR /F "tokens=1-4 delims=.-_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" %%a IN ("%~n1") DO CALL :version_key %%a %%b %%c %%d
IF NOT DEFINED KEYACC SET "KEYACC=0000"
SET "CANDKEY=V%KEYACC%"
IF NOT DEFINED SCAN_BESTKEY GOTO :fc_take
IF "%CANDKEY%" GTR "%SCAN_BESTKEY%" GOTO :fc_take
EXIT /B 0
:fc_take
SET "SCAN_BEST=%~f1"
SET "SCAN_BESTKEY=%CANDKEY%"
EXIT /B 0

:version_key
CALL :version_add %1
CALL :version_add %2
CALL :version_add %3
CALL :version_add %4
EXIT /B 0

:version_add
IF "%~1"=="" EXIT /B 0
SET "KEYT=000%~1"
SET "KEYT=%KEYT:~-4%"
SET "KEYACC=%KEYACC%%KEYT%"
EXIT /B 0

REM ----------------------------------------------------------------- save vbios
:run_save
MKDIR vbios_backups 2>NUL
SET "AMD_VBIOS_SAVED="
SET "FLASH_LOG=vbios_backups\flasher_out.log"
REM The flasher is called directly and its output is captured to a log file.
REM Parsing the log instead of a FOR /F over the command line keeps every
REM path safe - flasher folder, rom file - even when it contains spaces,
REM parentheses or non-ASCII characters.
"%FLASHER%" --accept-EULA --savefile-at-end -s 0 > "%FLASH_LOG%" 2>&1
FOR /F "usebackq tokens=1-12*" %%A IN ("%FLASH_LOG%") DO IF "%%A"=="SUCCESS:" (SET "AMD_VBIOS_SAVED=%%~M") ELSE IF NOT "%%A %%B %%C %%D"=="AMD IFWI Flasher Tool" ECHO Saving VBIOS - %%A %%B %%C %%D %%E %%F %%G %%H %%I %%J %%K %%L %%M
REM The saved-file name has to be reduced to its bare file name first: newer
REM builds (5.0.879) report the FULL path in the SUCCESS line, and the VBIOS is
REM written next to the flasher when it lives in a subfolder (.\Software\...).
SET "AMD_VBIOS_FILE="
FOR %%F IN ("%AMD_VBIOS_SAVED%") DO SET "AMD_VBIOS_FILE=%%~nxF"
SET "AMD_VBIOS_PRETTY=%AMD_VBIOS_FILE:_0000.=_bus%"
SET "AMD_VBIOS_PRETTY=%AMD_VBIOS_PRETTY:.00.0_=_pn%"
IF NOT DEFINED AMD_VBIOS_PRETTY GOTO :rs_failed
MOVE /Y "%AMD_VBIOS_SAVED%" "vbios_backups\%AMD_VBIOS_PRETTY%.rom" >NUL 2>&1
IF ERRORLEVEL 1 GOTO :rs_failed
IF NOT EXIST "vbios_backups\%AMD_VBIOS_PRETTY%.rom" GOTO :rs_failed
SET "SAVED_SIZE="
FOR %%I IN ("vbios_backups\%AMD_VBIOS_PRETTY%.rom") DO SET "SAVED_SIZE=%%~zI"
IF NOT DEFINED SAVED_SIZE GOTO :rs_failed
IF "%SAVED_SIZE%"=="0" GOTO :rs_failed
SET "AMD_VBIOS_SAVED_INFO=backed up as vbios_backups\%AMD_VBIOS_PRETTY%.rom size %SAVED_SIZE% bytes"
EXIT /B 0

:rs_failed
ECHO ERROR: saving VBIOS backup failed, nothing done
ECHO Disable autostarted hardware monitoring and GPU vendor apps and services
ECHO Reboot, Power Off, Power On to enforce full cycle on Windows and GPU, then try again
ECHO If this not help - the AMD flash tool can't be used in this case.
EXIT /B 1

REM ------------------------------------------------------------------ flash vbios
:run_flash
ECHO.
ECHO NOTE: Original VBIOS %AMD_VBIOS_SAVED_INFO%
ECHO.
SET /P "=Flashing started for %AMD_VBIOS_TO_FLASH%..." <NUL
ECHO.
ECHO The flasher output follows, please wait...
"%FLASHER%" --accept-EULA -fv --debug-log-status=false -p 0 "%AMD_VBIOS_TO_FLASH%" > "%FLASH_LOG%" 2>&1
TYPE "%FLASH_LOG%"

FINDSTR /I /C:"Please REBOOT the System" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :rf_reboot
FINDSTR /I /C:"already flashed" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :run_same_image
FINDSTR /I /C:"mismatch" /C:"is not same" /C:"Use -f" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :run_forced_flash

ECHO.
ECHO ERROR: Flashing status unknown - see vbios_backups\flasher_out.log
ECHO Disable autostarted hardware monitoring and GPU vendor apps and services
ECHO Reboot, Power Off, Power On to enforce full cycle on Windows and GPU, then try again
ECHO If this not help - the AMD flash tool can't be used in this case.
EXIT /B 1

REM ------------------------------------------------------- same image already flashed
REM  0xA00003FC "Same IFWI image already flashed. Use -fa ..." - the ROM equals
REM  what is on the card. AMD's own procedure says the SPIROM has two partitions,
REM  so writing the second one means flashing the same image once more: that is
REM  exactly what -fa is for. Without confirmation nothing is written.
:run_same_image
ECHO.
ECHO NOTE: This image is identical to the IFWI that is already flashed.
FOR /F "tokens=1,* delims=:" %%A IN ('FINDSTR /I /C:"Existing IFWI version" "%FLASH_LOG%"') DO ECHO   on the card :%%B
FOR /F "tokens=1,* delims=:" %%A IN ('FINDSTR /I /C:"IFWI version to be flashed" "%FLASH_LOG%"') DO ECHO   in the file :%%B
ECHO.
ECHO Re-flashing an identical image only makes sense to write the second SPIROM
ECHO partition (AMD procedure: flash, reboot, flash again, reboot).
SET "SAME_CHOICE="
SET /P "SAME_CHOICE=Type Y to force the re-flash with -fa, anything else aborts: "
IF /I NOT "%SAME_CHOICE%"=="Y" GOTO :rf_same_skip
ECHO.
ECHO Forcing the re-flash with -fa ...
"%FLASHER%" --accept-EULA -fa --debug-log-status=false -p 0 "%AMD_VBIOS_TO_FLASH%" > "%FLASH_LOG%" 2>&1
TYPE "%FLASH_LOG%"
FINDSTR /I /C:"Please REBOOT the System" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :rf_reboot
ECHO.
ECHO ERROR: re-flash failed - see vbios_backups\flasher_out.log
EXIT /B 1

:rf_same_skip
ECHO.
ECHO Note: Nothing to do - the image is already flashed, card untouched.
EXIT /B 0

:rf_already
ECHO.
ECHO Note: Nothing to do - the flasher reports that this image is already flashed.
EXIT /B 0

:rf_reboot
ECHO.
ECHO OK: Flashing done. Please REBOOT the System to Complete VBIOS Update.
ECHO NOTE: Original VBIOS %AMD_VBIOS_SAVED_INFO%
EXIT /B 0

REM ------------------------------------------------------------ forced flash path
REM  5.0.879 refuses an image when the IFWI version, the SSID or the PartNumber
REM  does not match the card, and names the bypass flag in its error message:
REM      -fv = IFWI version (downgrade)   -fp = PartNumber
REM  The forced flash below therefore passes all three, after an explicit "Y".
:run_forced_flash
ECHO.
ECHO NOTE: The flasher refused this image - its own words:
FINDSTR /I /C:"mismatch" /C:"is not same" /C:"Use -f" "%FLASH_LOG%"
ECHO.
ECHO A forced flash (-fv -fp) ignores the version, subsystem ID and
ECHO PartNumber checks. If the image is not meant for this card, the GPU can be
ECHO bricked and would then have to be recovered on a second PC.
CALL :force_confirm
IF ERRORLEVEL 1 GOTO :ff_aborted
ECHO.
ECHO Forcing the flash with -fv -fp ...
"%FLASHER%" --accept-EULA -fv -fp --debug-log-status=false -p 0 "%AMD_VBIOS_TO_FLASH%" > "%FLASH_LOG%" 2>&1
TYPE "%FLASH_LOG%"
FINDSTR /I /C:"Please REBOOT the System" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :rf_reboot
FINDSTR /I /C:"already flashed" "%FLASH_LOG%" >NUL
IF NOT ERRORLEVEL 1 GOTO :rf_already
ECHO.
ECHO ERROR: forced flashing failed - see vbios_backups\flasher_out.log
EXIT /B 1

:force_confirm
ECHO.
ECHO If the new VBIOS would not work - you would have to follow this instruction:
ECHO - Get a PC running Windows 10 without Secure Boot
ECHO - Full power off, disconnect all external GPUs, attach display to integrated GPU
ECHO - Enter BIOS setup, enable "Compatibility Support Mode(CSM)" and integrated GPU priority
ECHO - Uninstall AMD GPU driver
ECHO - Full power off, plug the bad-flashed GPU, keeping display to integrated video
ECHO - Copy to that prepared PC the original VBIOS
ECHO     %AMD_VBIOS_SAVED_INFO%
ECHO - Use this tool (or older AmdVBFlash 2.93 for Navi1x) to rollback original VBIOS
ECHO - ... and even all this may not help!
ECHO.
ECHO If you have Windows 10 with integrated video and BIOS options mentioned above
ECHO and the instructions looks completely clear for you - make photo of those steps!
ECHO Exit all apps including background hardware monitoring services before continue.
ECHO Then type Y and press Enter to FORCE VBIOS having a high chance of bricking your GPU!
ECHO Close this window to abort if you don't understand something or not sure.
SET /P "RISKY_CHOICE="
IF /I NOT "%RISKY_CHOICE%"=="Y" EXIT /B 1
EXIT /B 0

:ff_aborted
ECHO.
ECHO Note: bricking GPU not confirmed, nothing changed!
EXIT /B 1

REM ===========================================================================
REM  Diagnostics - these never change anything
REM ===========================================================================
:do_list
CALL :resolve_flasher
IF ERRORLEVEL 1 EXIT /B 1
FOR %%F IN ("%FLASHER_DIR%\amdvbflash*.exe") DO IF EXIST "%%~fF" ECHO %%~fF
EXIT /B 0

:do_choose
PUSHD "%HERE%" >NUL 2>&1
CALL :choose_texts
SET "AUTO_PICK_ONLY=1"
CALL :resolve_flasher
SET "AUTO_PICK_ONLY="
IF ERRORLEVEL 1 GOTO :ch_none

ECHO.
CALL :print_credit
ECHO.
SET "DIRSHOW=%FLASHER_DIR%"
IF "%DIRSHOW:~-1%"=="\" SET "DIRSHOW=%DIRSHOW:~0,-1%"
ECHO %TXT_FOLDER% "%DIRSHOW%"
ECHO %TXT_AUTO% "%FLASHER_NAME%"
ECHO.
ECHO %TXT_HEAD1%
ECHO %TXT_HEAD2%
SET "CHOOSE_IDX=0"
CALL :choose_folder "%HERE%"
CALL :choose_folder "%HERE%Software"
CALL :choose_folder "%HERE%..\Software"
ECHO.
IF NOT EXIST "%PIN_FILE%" GOTO :ch_pin_none
FOR /F "usebackq delims=" %%L IN ("%PIN_FILE%") DO IF NOT DEFINED CUR_PIN IF NOT "%%L"=="" SET "CUR_PIN=%%~L"
IF NOT DEFINED CUR_PIN GOTO :ch_pin_none
ECHO %TXT_PINNED% "%CUR_PIN%"
GOTO :ch_pin_done

:ch_pin_none
ECHO %TXT_UNPINNED%

:ch_pin_done
ECHO.
SET "SEL="
SET /P "SEL=%TXT_PROMPT%"
IF NOT DEFINED SEL GOTO :ch_abort
IF "%SEL%"=="0" GOTO :ch_clear
ECHO %SEL%|FINDSTR /R /C:"^[1-9][0-9]*$" >NUL
IF ERRORLEVEL 1 GOTO :ch_invalid
SET /A WANT=SEL+0
SET "CHOOSE_IDX=0"
SET "CHOSEN="
CALL :choose_folder_match "%HERE%"
CALL :choose_folder_match "%HERE%Software"
CALL :choose_folder_match "%HERE%..\Software"
IF NOT DEFINED CHOSEN GOTO :ch_invalid
FOR %%F IN ("%CHOSEN%") DO SET "CHOSEN_NAME=%%~nxF"
> "%PIN_FILE%" ECHO %CHOSEN_NAME%
ECHO.
ECHO %TXT_PINNED_OK% "%CHOSEN_NAME%"
POPD
EXIT /B 0

:choose_folder
SET "CF="
FOR %%F IN ("%~1\amdvbflash*.exe") DO IF EXIST "%%~fF" SET "CF=1"
IF NOT DEFINED CF EXIT /B 0
ECHO.
ECHO   [%~1]
FOR %%F IN ("%~1\amdvbflash*.exe") DO IF EXIST "%%~fF" CALL :choose_line "%%~fF"
EXIT /B 0

:choose_folder_match
FOR %%F IN ("%~1\amdvbflash*.exe") DO IF EXIST "%%~fF" CALL :choose_match "%%~fF"
EXIT /B 0

:choose_line
SET /A CHOOSE_IDX+=1
SET "KEYACC="
FOR /F "tokens=1-4 delims=.-_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz" %%a IN ("%~n1") DO CALL :version_key %%a %%b %%c %%d
IF NOT DEFINED KEYACC SET "KEYACC=0000"
SET "KCOL=V%KEYACC%                    "
SET "MARK="
IF /I "%~f1"=="%FLASHER%" SET "MARK=%TXT_MARK%"
ECHO   %CHOOSE_IDX%  %KCOL:~0,20%  %~nx1%MARK%
EXIT /B 0

:choose_match
SET /A CHOOSE_IDX+=1
IF "%CHOOSE_IDX%"=="%WANT%" SET "CHOSEN=%~f1"
EXIT /B 0

:ch_clear
IF EXIST "%PIN_FILE%" DEL "%PIN_FILE%" >NUL 2>&1
ECHO.
ECHO %TXT_CLEARED%
POPD
EXIT /B 0

:ch_abort
ECHO.
ECHO %TXT_ABORT%
POPD
EXIT /B 0

:ch_invalid
ECHO.
ECHO %TXT_INVALID%
POPD
EXIT /B 1

:ch_none
ECHO %TXT_NONE%
POPD
EXIT /B 1

REM ------------------------------------------------------------------- UI texts
REM  NAVI_LANG=zh gives Chinese texts, everything else gives English ones.
:choose_texts
SET "TXT_CREDIT=Made by WanChuGeMingTang - the warmer guide to retro digital fun"

SET "TXT_FOLDER=Folder   :"
SET "TXT_AUTO=Automatic:"
SET "TXT_HEAD1=  #  version key         flasher"
SET "TXT_HEAD2=---  ------------------  ------------------------------------------"
SET "TXT_PINNED=Used now :"
SET "TXT_UNPINNED=Used now : nothing pinned - the automatic pick is used"
SET "TXT_PROMPT=Number to pin (0 = automatic, Enter = abort): "
SET "TXT_PINNED_OK=OK: pinned"
SET "TXT_CLEARED=OK: pin removed - the automatic pick is used again."
SET "TXT_ABORT=Nothing changed."
SET "TXT_INVALID=ERROR: invalid number - nothing changed."
SET "TXT_NONE=ERROR: no amdvbflash*.exe found."
SET "TXT_MARK=   ^<-- automatic"
EXIT /B 0


REM ------------------------------------------------------------- credit signature
REM  Shown in a soft amber colour: noticeable, but not glaring. PowerShell's
REM  Write-Host is used because cmd.exe cannot colour a single line without VT
REM  escape sequences (which depend on the host / registry), and the "color"
REM  command would repaint the whole window.
REM  Falls back to plain text when PowerShell is not available.
:print_credit
SET "CREDIT_LINE=  %TXT_CREDIT%"
WHERE powershell >NUL 2>&1
IF ERRORLEVEL 1 GOTO :pc_plain
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host $env:CREDIT_LINE -ForegroundColor DarkYellow" 2>NUL
IF NOT ERRORLEVEL 1 EXIT /B 0
:pc_plain
ECHO %CREDIT_LINE%
EXIT /B 0

:do_selftest
PUSHD "%HERE%" >NUL 2>&1
CALL :choose_texts
ECHO AutoAMDVBFlash - self test
CALL :print_credit
ECHO Folder  : %HERE%
ECHO Script  : %SELF%
ECHO Pin file: %PIN_FILE%
ECHO.

FLTMC >NUL 2>&1
IF ERRORLEVEL 1 ECHO Admin   : NO
IF NOT ERRORLEVEL 1 ECHO Admin   : YES
IF EXIST "driver\admin_load_driver.bat" ECHO Driver  : driver folder OK
IF NOT EXIST "driver\admin_load_driver.bat" ECHO Driver  : driver folder MISSING
IF EXIST "%PIN_FILE%" ECHO Pinned  : %PIN_FILE%
IF NOT EXIST "%PIN_FILE%" ECHO Pinned  : no flasher.txt - automatic choice
ECHO.

CALL :resolve_flasher
IF ERRORLEVEL 1 GOTO :st_noflasher
ECHO Flasher : %FLASHER_NAME%
ECHO Path    : %FLASHER%
ECHO Count   : %FLASHER_COUNT%
FOR %%F IN ("%FLASHER_DIR%\amdvbflash*.exe") DO IF EXIST "%%~fF" ECHO    - %%~nxF
ECHO.
IF "%ROM%"=="" ECHO Rom     : none - save-only mode would run
IF NOT "%ROM%"=="" ECHO Rom     : "%ROM%"
POPD
EXIT /B 0

:st_noflasher
ECHO Flasher : NONE FOUND - nothing would be flashed
POPD
EXIT /B 1
