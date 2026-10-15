#!/usr/bin/env bash
# TwoPlans - 把 iOS 工程推到 GitHub，让 Actions 编出 ipa
# 用法：在 Git Bash 里执行   bash ios/publish-to-github.sh
set -e

cd "$(dirname "$0")/.."
ROOT="$PWD"
echo "仓库根目录： $ROOT"

mkdir -p .github/workflows
cp ios/build-ipa.yml .github/workflows/build-ipa.yml
echo "已复制 workflow 到 .github/workflows/build-ipa.yml"

git init -b main 2>/dev/null || true

# git 没配过提交身份时，给这个仓库设个默认作者，免得 commit 直接失败
if ! git config user.email >/dev/null 2>&1; then
  git config user.email "twoplans@local"
  git config user.name "twoplans"
fi

if command -v gh >/dev/null 2>&1; then
  echo "检测到 GitHub CLI，走自动建仓库流程"
  gh auth status || gh auth login
  git add -A
  git commit -m "TwoPlans: iOS app plus Actions IPA build" || echo "没有变更可提交，继续"
  SLUG=$(gh repo create twoplans --private --source=. --remote=origin --push 2>/dev/null | grep -o 'github.com/[^ ]*' | head -1 | sed 's#https://github.com/##')
  if [ -z "$SLUG" ]; then SLUG=$(gh repo view --json nameWithOwner -q .nameWithOwner); fi
else
  echo "没装 GitHub CLI，走手动流程"
  echo "1) 打开 https://github.com/new 新建一个空仓库（建议名 twoplans，不要勾 README）"
  read -r -p "2) 输入仓库 slug（用户名/仓库名）: " SLUG
  [ -z "$SLUG" ] && { echo "没输入，退出"; exit 1; }
  git remote remove origin 2>/dev/null || true
  git remote add origin "https://github.com/${SLUG}.git"
  git add -A
  git commit -m "TwoPlans: iOS app plus Actions IPA build" || echo "没有变更可提交，继续"
  git branch -M main
  echo "推送时如需密码，请填 Personal Access Token（不是账号密码）：https://github.com/settings/tokens 勾选 repo"
  git push -u origin main
fi

echo
echo "推送完成。构建页面（等 3-5 分钟）：https://github.com/${SLUG}/actions"
echo "IPA 下载页面：https://github.com/${SLUG}/releases"
echo
echo "iPhone 上：Safari 打开 Releases 里的 TwoPlans.ipa 链接 → 分享 → TrollStore → Install"
