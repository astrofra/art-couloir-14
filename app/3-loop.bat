:loop
bin\hg_lua-win-x64\lua.exe main.lua
timeout /t 1 >nul
goto loop
pause