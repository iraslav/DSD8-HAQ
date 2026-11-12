@echo off
REM run_icarus_tests.bat -- runs every DSD-8 test with Icarus Verilog on Windows.
REM Double-click it, or run it from a Command Prompt opened in this folder.
REM Needs: Icarus Verilog 11 or 12 (iverilog, vvp) and Python 3 on the PATH.

cd /d "%~dp0"
echo Running in: %CD%

where iverilog >nul 2>nul || (echo ERROR: iverilog not found. Install Icarus Verilog and tick "Add to PATH". & pause & exit /b 1)
where vvp      >nul 2>nul || (echo ERROR: vvp not found. Install Icarus Verilog and tick "Add to PATH". & pause & exit /b 1)

echo Icarus version:
iverilog -V 2>&1 | findstr /B /C:"Icarus Verilog version"
iverilog -V 2>&1 | findstr /C:"version 0." >nul && (
  echo.
  echo WARNING: this is Icarus Verilog 0.9.x from 2013. It does not support all of
  echo Verilog-2005. Uninstall it and install version 12 from bleyer.org/icarus.
  echo.
  pause
)

set PY=python
where python >nul 2>nul || set PY=py -3

if not exist build mkdir build

echo.
echo ===== 1. Module testbenches (expect 12 / 12 passed) =====
%PY% scripts\run_unit_tests.py

echo.
echo ===== 2. Conformance T01-T40 (expect 42 / 42 passed) =====
%PY% scripts\run_conformance.py

echo.
echo ===== 3. Extra and random programs (expect 17 / 17 passed) =====
%PY% scripts\run_conformance.py --dir tests\extra

echo.
echo ===== 4. Board top level in simulation (expect LEDs=5b and PASS) =====
iverilog -g2005 -o build\top.vvp rtl\alu.v rtl\btn_debounce.v rtl\control_unit.v rtl\data_memory.v rtl\dsd8_cpu.v rtl\dsd8_top.v rtl\flags_reg.v rtl\instr_decoder.v rtl\instr_memory.v rtl\io_bus.v rtl\prog_counter.v rtl\register_file.v rtl\seg7_driver.v sim\peripherals.v tb\tb_dsd8_top.v && vvp build\top.vvp

echo.
echo Done. Scroll up and check every section says PASS.
pause
