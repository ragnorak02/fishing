@echo off
setlocal
set GODOT_EXE=C:\Users\nick\Downloads\Godot_v4.6-stable_win64.exe\Godot_v4.6-stable_win64.exe
"%GODOT_EXE%" --headless --path "%~dp0.." --script res://tests/run_tests.gd 2>nul
if exist "%~dp0test-results.json" (
    type "%~dp0test-results.json"
) else (
    echo {"status":"fail","testsTotal":0,"testsPassed":0,"durationMs":0,"timestamp":"","details":[{"name":"runner","status":"fail","message":"Test runner did not produce results"}]}
)
