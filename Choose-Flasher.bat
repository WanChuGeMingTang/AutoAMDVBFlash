@ECHO OFF
CHCP 936 >NUL 2>&1
REM ===========================================================================
REM  Choose-Flasher.bat  -  AutoAMDVBFlash flasher picker, ENGLISH prompts
REM  (选择刷写器.bat is the same thing with Chinese prompts)
REM  本脚本由「玩出个名堂——更具温度的怀旧数码玩乐指南」制作
REM ===========================================================================
SETLOCAL EnableExtensions DisableDelayedExpansion
SET "NAVI_LANG=en"
CALL "%~dp0AutoAMDVBFlash.bat" --choose-flasher
ECHO.
PAUSE
