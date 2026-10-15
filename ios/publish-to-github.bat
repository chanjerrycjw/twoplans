@echo off
rem ==========================================================
rem  TwoPlans - push iOS project to GitHub, let Actions build IPA
rem  Output is pure ASCII on purpose: Chinese in .bat shows mojibake
rem  on some cmd codepages. See ioS README for Chinese instructions.
rem ==========================================================
setlocal
cd /d "%~dp0"

echo.
echo === TwoPlans IPA builder ===
echo This pushes the project to GitHub, where macOS Actions compiles
echo TwoPlans.ipa for you. Windows itself cannot build iOS binaries.
echo.

where gh >nul 2>nul
if %errorlevel%==0 goto usegh

echo [Mode A] No GitHub CLI found, manual upload.
echo.
echo Step 1 - open https://github.com/new and create an EMPTY repo.
echo          Suggested name: twoplans
echo          Do NOT tick "Add README / .gitignore / license".
echo.
set /p SLUG=Step 2 - type your repo slug like username/repo : 
if "%SLUG%"=="" echo Nothing typed, exiting. & goto finish

if not exist "..\.github\workflows" mkdir "..\.github\workflows"
copy /Y "build-ipa.yml" "..\.github\workflows\build-ipa.yml" >nul
echo Copied workflow into .github\workflows\
cd ..
git init -b main
git config user.email >nul 2>nul
if errorlevel 1 goto setid
goto afterid
:setid
git config user.email twoplans@local
git config user.name twoplans
:afterid
git remote remove origin 2>nul
git remote add origin https://github.com/%SLUG%.git
git add -A
git commit -m "TwoPlans: iOS app plus Actions IPA build"
if errorlevel 1 goto nocommit
git branch -M main
echo.
echo Step 3 - pushing. When asked:
echo   user     = your GitHub username
echo   password = Personal Access Token, NOT your account password
echo   token    = https://github.com/settings/tokens  (scope: repo)
echo.
git push -u origin main
if errorlevel 1 goto pushfail
goto opened

:usegh
echo [Mode B] GitHub CLI detected.
cd ..
call gh auth status
if errorlevel 1 call gh auth login
if not exist "..\.github\workflows" mkdir "..\.github\workflows"
if not exist ".github\workflows" mkdir ".github\workflows"
copy /Y "ios\build-ipa.yml" ".github\workflows\build-ipa.yml" >nul
git init -b main
git config user.email >nul 2>nul
if errorlevel 1 goto setid
goto afterid
:setid
git config user.email twoplans@local
git config user.name twoplans
:afterid
git add -A
git commit -m "TwoPlans: iOS app plus Actions IPA build"
if errorlevel 1 goto nocommit
call gh repo create twoplans --private --source=. --remote=origin --push
if errorlevel 1 goto pushfail
for /f "delims=" %%r in ('gh repo view --json nameWithOwner -q .nameWithOwner') do set SLUG=%%r
goto opened

:nocommit
echo.
echo git commit failed - nothing to commit or git is not set up. Fine, continuing anyway.

:pushfail
echo.
echo Push failed. Check: repo exists? token has repo scope? network OK?
echo Then run this script again.

:opened
echo.
echo Done. Watch the build here (about 3-5 minutes):
start https://github.com/%SLUG%/actions
echo Then grab the IPA here:
start https://github.com/%SLUG%/releases
echo.
echo On iPhone: open the TwoPlans.ipa link in Safari, tap Share, pick
echo TrollStore, tap Install. No re-signing, never expires.

:finish
echo.
pause
