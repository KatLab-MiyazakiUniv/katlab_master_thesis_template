#!/usr/bin/env bash
set -euo pipefail

# テンプレートリポジトリから更新を同期するスクリプト
# このスクリプトは、テンプレートから作成された派生リポジトリで実行します

TEMPLATE_REPO="https://github.com/KatLab-MiyazakiUniv/katlab_master_thesis_template.git"
TEMPLATE_REMOTE="template"
TEMPLATE_BRANCH="main"

# カラー出力
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Git リポジトリのチェック
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  log_error "このディレクトリは Git リポジトリではありません"
  exit 1
fi

# 作業ディレクトリのクリーンチェック
if [[ -n $(git status --porcelain) ]]; then
  log_warn "作業ディレクトリに未コミットの変更があります"
  echo ""
  git status --short
  echo ""
  read -p "続行しますか？ (y/N): " -n 1 -r
  echo ""
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "同期をキャンセルしました"
    exit 0
  fi
fi

# テンプレート remote の追加または更新
log_info "テンプレートリポジトリを設定中..."
if git remote get-url "$TEMPLATE_REMOTE" > /dev/null 2>&1; then
  log_info "既存の '$TEMPLATE_REMOTE' remote を更新します"
  git remote set-url "$TEMPLATE_REMOTE" "$TEMPLATE_REPO"
else
  log_info "'$TEMPLATE_REMOTE' remote を追加します"
  git remote add "$TEMPLATE_REMOTE" "$TEMPLATE_REPO"
fi

# テンプレートの最新情報を取得
log_info "テンプレートリポジトリから最新情報を取得中..."
if ! git fetch "$TEMPLATE_REMOTE"; then
  log_error "テンプレートリポジトリからの取得に失敗しました"
  exit 1
fi

# 現在のブランチを取得
CURRENT_BRANCH=$(git branch --show-current)
log_info "現在のブランチ: $CURRENT_BRANCH"

# テンプレートとの差分を表示
log_info "テンプレートとの差分を確認中..."
echo ""
git log --oneline --decorate --graph HEAD.."$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" --color=always || true
echo ""

COMMITS_BEHIND=$(git rev-list --count HEAD.."$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" 2>/dev/null || echo "0")
if [[ "$COMMITS_BEHIND" == "0" ]]; then
  log_success "テンプレートは最新です。更新の必要はありません。"
  exit 0
fi

log_warn "テンプレートに $COMMITS_BEHIND 件の新しいコミットがあります"
echo ""

# 同期方法の選択
echo "同期方法を選択してください："
echo "  1) マージ（推奨）- テンプレートの変更を現在のブランチにマージします"
echo "  2) リベース - テンプレートの変更を現在のブランチの履歴に取り込みます"
echo "  3) 差分確認のみ - ファイル単位の差分を表示します"
echo "  4) キャンセル"
echo ""
read -p "選択 (1-4): " -n 1 -r SYNC_METHOD
echo ""

case "$SYNC_METHOD" in
  1)
    log_info "マージを実行します..."
    if git merge "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH" --no-edit; then
      log_success "テンプレートの更新をマージしました"
      log_info "以下のコマンドで push できます："
      echo "  git push origin $CURRENT_BRANCH"
    else
      log_error "マージでコンフリクトが発生しました"
      log_info "コンフリクトを解決してから以下を実行してください："
      echo "  git add <解決したファイル>"
      echo "  git commit"
      exit 1
    fi
    ;;
  2)
    log_info "リベースを実行します..."
    if git rebase "$TEMPLATE_REMOTE/$TEMPLATE_BRANCH"; then
      log_success "テンプレートの更新をリベースしました"
      log_warn "リベースによりコミット履歴が書き換わっています"
      log_info "以下のコマンドで push できます（force push が必要）："
      echo "  git push origin $CURRENT_BRANCH --force-with-lease"
    else
      log_error "リベースでコンフリクトが発生しました"
      log_info "コンフリクトを解決してから以下を実行してください："
      echo "  git add <解決したファイル>"
      echo "  git rebase --continue"
      log_info "リベースをキャンセルする場合："
      echo "  git rebase --abort"
      exit 1
    fi
    ;;
  3)
    log_info "ファイル単位の差分を表示します..."
    echo ""
    git diff --stat HEAD.."$TEMPLATE_REMOTE/$TEMPLATE_BRANCH"
    echo ""
    log_info "詳細な差分を見るには以下を実行してください："
    echo "  git diff HEAD..$TEMPLATE_REMOTE/$TEMPLATE_BRANCH"
    ;;
  4|*)
    log_info "同期をキャンセルしました"
    exit 0
    ;;
esac
