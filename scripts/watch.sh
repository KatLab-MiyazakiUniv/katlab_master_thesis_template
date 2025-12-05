#!/usr/bin/env bash
set -uo pipefail

# Determine workspace directory
if [[ -f /.dockerenv ]]; then
  WORKSPACE="/workspace"
else
  WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

cd "$WORKSPACE" || {
  echo "[ERROR] Cannot change directory to $WORKSPACE" >&2
  exit 1
}

# ログ出力関数
log_info() {
  echo "[INFO] $*"
}

log_warn() {
  echo "[WARN] $*"
}

log_error() {
  echo "[ERROR] $*" >&2
}

log_debug() {
  [[ "${DEBUG:-}" == "1" ]] && echo "[DEBUG] $*"
}

# Configuration
MAIN_TEX="paper.tex"
WATCH_DIR="chapters"
BUILD_DIR="build"
PID_FILE="$WORKSPACE/.watch.pid"

# Compile paper.tex using latexmk
compile_paper() {
  log_info "Compiling ${MAIN_TEX}..."

  if LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 latexmk -pdfdvi -outdir=build "$MAIN_TEX"; then
    # Copy PDF from build to root directory
    if [[ -f "build/paper.pdf" ]]; then
      cp "build/paper.pdf" "paper.pdf"
      log_info "Compilation successful - PDF: paper.pdf"
    else
      log_warn "Compilation completed but PDF not found in build directory"
    fi
    return 0
  else
    log_error "Compilation failed"
    # Retry with full-compile.sh if latexmk fails
    log_info "Retrying with full-compile.sh --retry..."
    if bash "$WORKSPACE/scripts/full-compile.sh" --retry; then
      log_info "Retry successful"
      return 0
    else
      log_error "Retry failed"
      return 1
    fi
  fi
}

# コンパイル進行中フラグ
compilation_in_progress=0

# クリーンアップ関数
cleanup() {
  log_info "Watch stopped"
  rm -f "$PID_FILE"
  exit 0
}

# シグナルハンドリング
trap cleanup SIGINT SIGTERM EXIT

# PID ファイルをチェック（既存プロセスの確認）
if [[ -f "$PID_FILE" ]]; then
  old_pid=$(cat "$PID_FILE" 2>/dev/null)
  if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
    log_warn "Watch process already running (PID: $old_pid)"
    log_warn "Terminating old process..."
    kill "$old_pid" 2>/dev/null || true
    sleep 0.5
  fi
  rm -f "$PID_FILE"
fi

# 現在のプロセスの PID を記録
echo $$ > "$PID_FILE"
log_info "Watch process started (PID: $$)"

log_info "Using polling method for Docker mount compatibility"
log_info "Watching: ${WATCH_DIR}/**/*.tex"

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# ポーリング監視
declare -A file_times

# 初期ファイル時刻を記録 (chapters/ と paper.bib)
while IFS= read -r -d '' file; do
  file_times["$file"]=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
  log_info "Tracking: $file"
done < <(find "$WATCH_DIR" -name "*.tex" -type f -print0 2>/dev/null)

# paper.bib も監視対象に追加
if [[ -f "paper.bib" ]]; then
  file_times["paper.bib"]=$(stat -c %Y "paper.bib" 2>/dev/null || stat -f %m "paper.bib")
  log_info "Tracking: paper.bib"
fi

# メインの監視ループ
while true; do
  # chapters/ 内の .tex ファイルの変更を監視
  while IFS= read -r -d '' file; do
    current=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
    if [[ "${file_times[$file]:-}" != "$current" ]]; then
      # コンパイル進行中の場合はスキップ
      if [[ "$compilation_in_progress" == "1" ]]; then
        log_debug "Skipping compilation (already in progress)"
        file_times["$file"]=$current
        continue
      fi

      file_times["$file"]=$current
      log_info "Change detected in: $file"

      # コンパイル開始フラグを設定
      compilation_in_progress=1

      # 短い待機時間で複数変更をまとめる
      sleep 0.5

      # 再度時刻をチェックして、さらに変更があった場合は最新を取得
      latest=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file")
      if [[ "$current" != "$latest" ]]; then
        file_times["$file"]=$latest
        log_debug "Multiple changes detected, using latest version"
      fi

      compile_paper

      # コンパイル完了フラグをリセット
      compilation_in_progress=0
    fi
  done < <(find "$WATCH_DIR" -name "*.tex" -type f -print0 2>/dev/null)

  # paper.bib の変更を監視
  if [[ -f "paper.bib" ]]; then
    current=$(stat -c %Y "paper.bib" 2>/dev/null || stat -f %m "paper.bib")
    if [[ "${file_times[paper.bib]:-}" != "$current" ]]; then
      # コンパイル進行中の場合はスキップ
      if [[ "$compilation_in_progress" == "1" ]]; then
        log_debug "Skipping compilation (already in progress)"
        file_times["paper.bib"]=$current
      else
        file_times["paper.bib"]=$current
        log_info "Change detected in: paper.bib"

        # コンパイル開始フラグを設定
        compilation_in_progress=1

        # 短い待機時間で複数変更をまとめる
        sleep 0.5

        compile_paper

        # コンパイル完了フラグをリセット
        compilation_in_progress=0
      fi
    fi
  fi

  sleep 1
done
