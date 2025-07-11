@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

:: Buat folder docs jika belum ada
IF NOT EXIST docs (
    mkdir docs
)

:: Daftar pertemuan (ganti kalau jumlah berbeda)
FOR %%P IN (p5 p6) DO (

    echo ============================
    echo Building Flutter project %%P
    echo ============================

    :: Cek apakah folder project ada
    IF EXIST %%P (
        pushd %%P

        :: Jalankan build
        flutter build web

        :: Kembali ke root folder
        popd

        :: Buat ulang folder tujuan di docs
        IF EXIST docs\%%P (
            rmdir /S /Q docs\%%P
        )
        mkdir docs\%%P

        :: Salin hasil build
        xcopy /E /I /Y %%P\build\web\* docs\%%P\

    ) ELSE (
        echo Folder %%P tidak ditemukan, dilewati.
    )
)

echo:
echo ===== DONE BUILDING =====
pause
