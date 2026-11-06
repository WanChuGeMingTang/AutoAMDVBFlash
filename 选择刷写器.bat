@ECHO OFF
CHCP 936 >NUL 2>&1
REM ===========================================================================
REM  选择刷写器.bat  -  AutoAMDVBFlash 刷写程序选择器，中文提示
REM  （Choose-Flasher.bat 是同样的功能，英文提示版）
REM  本脚本由「玩出个名堂——更具温度的怀旧数码玩乐指南」制作
REM ===========================================================================
SETLOCAL EnableExtensions DisableDelayedExpansion
SET "NAVI_LANG=zh"
CALL "%~dp0AutoAMDVBFlash.bat" --choose-flasher
ECHO.
PAUSE
