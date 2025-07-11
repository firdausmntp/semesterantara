@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

cd /d "%~dp0"

IF NOT EXIST docs (
  mkdir docs
)
echo > docs\.nojekyll

REM sesuaikan nama projek utama
FOR %%M IN (pmobile kejar) DO (
  IF EXIST %%M (
    REM deteksi subfolder p1, p2 itd
    for /D %%P in (%%M\*) do (
      echo Building %%P
      pushd %%P
        flutter clean
        flutter pub get
        set SUB=docs\%%M\%%~nP
        flutter build web --base-href=/semesterantara/%%M/%%~nP/
      popd
      rmdir /S /Q "%SUB%" 2>nul
      mkdir "%SUB%"
      xcopy /E /I /Y "%%P\build\web\*" "%SUB%\" 
    )
  )
)

echo Build dan copy selesai.
pause
