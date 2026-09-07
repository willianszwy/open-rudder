@echo off
REM Open Rudder - serve esta pasta em http://localhost:8000
REM A API Web Serial exige localhost ou HTTPS - abrir o .html direto pelo
REM Explorer (file://) nao funciona.

cd /d "%~dp0"
start "" http://localhost:8000/calibrador.html
python -m http.server 8000
