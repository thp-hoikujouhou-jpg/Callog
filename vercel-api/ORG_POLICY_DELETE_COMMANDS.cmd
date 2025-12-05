@echo off
REM Callog - 組織ポリシー削除スクリプト (Command Prompt)
REM ============================================================

echo ===== Step 1: 組織IDを取得 =====
echo.

REM 組織一覧を表示
gcloud organizations list

echo.
echo 上記の出力から組織ID（数字部分）をメモしてください
echo 例: 123456789012
echo.
set /p ORG_ID="組織IDを入力してください: "

echo.
echo ✅ 組織ID: %ORG_ID%
echo.

REM ===== Step 2: 現在の組織レベルのロールを確認 =====
echo ===== Step 2: 現在の組織レベルのロールを確認 =====
echo.
gcloud organizations get-iam-policy %ORG_ID% --flatten="bindings[].members" --format="table(bindings.role)" --filter="bindings.members:user:thp-hoikujouhou@tachanhao164.com"

echo.
pause

REM ===== Step 3: 組織ポリシー管理者ロールを追加 =====
echo.
echo ===== Step 3: 組織ポリシー管理者ロールを追加 =====
echo.
gcloud organizations add-iam-policy-binding %ORG_ID% --member="user:thp-hoikujouhou@tachanhao164.com" --role="roles/orgpolicy.policyAdmin"

echo.
pause

REM ===== Step 4: 組織レベルのポリシーを確認 =====
echo.
echo ===== Step 4: 組織レベルのポリシーを確認 =====
echo.
gcloud resource-manager org-policies describe iam.disableServiceAccountKeyCreation --organization=%ORG_ID%

echo.
pause

REM ===== Step 5: 組織ポリシーを削除 =====
echo.
echo ===== Step 5: 組織ポリシーを削除 =====
echo.
gcloud resource-manager org-policies delete iam.disableServiceAccountKeyCreation --organization=%ORG_ID%

echo.
echo ✅ ポリシーが削除されました
echo ⏰ 10-15分待機してからキー作成を試行してください
echo.
pause

REM ===== Step 6: Service Account Keyを作成 =====
echo.
echo ===== Step 6: Service Account Keyを作成 =====
echo ⏰ 10-15分経過しましたか？ (Y/N)
set /p WAIT_DONE="10-15分経過した場合は Y を入力: "

if /i "%WAIT_DONE%"=="Y" (
    echo.
    echo 🔑 Service Account Keyを作成中...
    gcloud iam service-accounts keys create C:\Users\admin\Downloads\callog-api-sa-key.json --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
    
    if %ERRORLEVEL% EQU 0 (
        echo.
        echo ✅ Service Account Keyの作成に成功しました！
        echo 📁 ファイル: C:\Users\admin\Downloads\callog-api-sa-key.json
    ) else (
        echo.
        echo ❌ Service Account Keyの作成に失敗しました
        echo もう少し待ってから再試行してください
    )
) else (
    echo.
    echo ⏰ 10-15分待機してから、以下のコマンドを実行してください:
    echo gcloud iam service-accounts keys create C:\Users\admin\Downloads\callog-api-sa-key.json --iam-account=callog-api-sa@callog-30758.iam.gserviceaccount.com
)

echo.
pause
