@echo off
rem Run Data Noise in compatibility (OpenGL) mode for older or integrated GPUs.
cd /d "%~dp0"
start "" "DataNoise.exe" --rendering-method gl_compatibility --rendering-driver opengl3
