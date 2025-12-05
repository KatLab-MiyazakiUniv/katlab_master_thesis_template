.PHONY: help build up down exec clean clean-all watch-chapters open-pdf setup dev restart rebuild stop logs paper.pdf kill-make

# メインTeXファイル
MAIN_TEX = paper.tex
OUTPUT_PDF = paper.pdf

# 既存の監視スクリプトのみを終了（PIDファイルベース）
define kill_watch_processes
	@echo "既存の監視プロセスをチェック中..."
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		if [ -f .watch.pid ]; then \
			OLD_PID=$$(cat .watch.pid 2>/dev/null); \
			if [ -n "$$OLD_PID" ] && kill -0 $$OLD_PID 2>/dev/null; then \
				echo "監視プロセス (PID: $$OLD_PID) を終了します..."; \
				kill $$OLD_PID 2>/dev/null || true; \
				sleep 0.5; \
			fi; \
			rm -f .watch.pid; \
		fi; \
	else \
		$(DOCKER_PREFIX) bash -c '\
			if [ -f /workspace/.watch.pid ]; then \
				OLD_PID=$$(cat /workspace/.watch.pid 2>/dev/null); \
				if [ -n "$$OLD_PID" ] && kill -0 $$OLD_PID 2>/dev/null; then \
					echo "監視プロセス (PID: $$OLD_PID) を終了します..."; \
					kill $$OLD_PID 2>/dev/null || true; \
					sleep 0.5; \
				fi; \
				rm -f /workspace/.watch.pid; \
			fi'; \
	fi
endef

# 実行環境の判定
IN_DEVCONTAINER := $(shell test -f /.dockerenv && test -f .devcontainer/devcontainer.json && echo 1 || echo 0)

# 環境に応じたコマンドの定義
ifeq ($(IN_DEVCONTAINER),1)
    # Dev Container 内での実行コマンド
    DOCKER_PREFIX =
    WORKSPACE_DIR = .
else
    # Docker Compose 経由での実行コマンド
    DOCKER_PREFIX = docker compose exec -T latex
    WORKSPACE_DIR = /workspace
endif

# 共通のコマンドを定義
LATEX_CMD       = $(DOCKER_PREFIX) bash -c "cd $(WORKSPACE_DIR) && LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 latexmk -pdfdvi -outdir=build $(MAIN_TEX)"
LATEX_CLEAN     = $(DOCKER_PREFIX) bash -c "cd $(WORKSPACE_DIR) && latexmk -c -outdir=build $(MAIN_TEX)"
LATEX_CLEAN_ALL = $(DOCKER_PREFIX) bash -c "cd $(WORKSPACE_DIR) && latexmk -C -outdir=build $(MAIN_TEX)"

# ファイル監視スクリプト（全環境対応）
WATCH_CMD       = $(DOCKER_PREFIX) bash $(WORKSPACE_DIR)/scripts/watch.sh

# デフォルトターゲット - paper.pdf をコンパイル後、chapters/ を監視
all: ## paper.tex をコンパイル後、chapters/ を監視
	$(call kill_watch_processes)
	@mkdir -p build
	@echo "Compiling $(MAIN_TEX)..."
	@$(LATEX_CMD)
	@$(DOCKER_PREFIX) bash -c "cd $(WORKSPACE_DIR) && if [ -f build/$(OUTPUT_PDF) ]; then cp build/$(OUTPUT_PDF) $(OUTPUT_PDF) && echo 'PDF copied to root: $(OUTPUT_PDF)'; fi"
	@echo ""
	@echo "初回コンパイル完了。監視モードを開始します..."
	@echo "終了するには Ctrl+C を押してください"
	@echo ""
	@echo "watching: chapters/**/*.tex (auto-detecting best method for your environment)"
	@$(WATCH_CMD)

.DEFAULT_GOAL := all

help: ## ヘルプを表示
	@echo "利用可能なコマンド:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

kill-make: ## 既存の監視プロセスを強制終了
	$(call kill_watch_processes)

# LaTeX 関連コマンド
paper.pdf: ## paper.tex をコンパイルし、paper.pdf を生成
	@mkdir -p build
	@echo "Compiling $(MAIN_TEX)..."
	@$(LATEX_CMD)
	@$(DOCKER_PREFIX) bash -c "cd $(WORKSPACE_DIR) && if [ -f build/$(OUTPUT_PDF) ]; then cp build/$(OUTPUT_PDF) $(OUTPUT_PDF) && echo 'PDF copied to root: $(OUTPUT_PDF)'; fi"

watch-chapters: ## chapters/ 内のファイル変更を監視してコンパイル
	$(call kill_watch_processes)
	@mkdir -p build
	@echo "watching: chapters/**/*.tex (auto-detecting best method for your environment)"
	@$(WATCH_CMD)

clean: ## LaTeX 中間ファイルを削除
	@echo "中間ファイル削除中..."
	@$(LATEX_CLEAN)

clean-all: ## すべての LaTeX 生成ファイルを削除
	@echo "生成ファイル完全削除中..."
	@$(LATEX_CLEAN_ALL)
	@$(DOCKER_PREFIX) rm -rf build/*

# ヘルパー関数: Docker環境チェック
define check_docker_env
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		echo "[ERROR] Dev Container 環境では Docker 関連コマンドは使用できません"; \
		exit 1; \
	fi
endef

# ヘルパー関数: 環境別メッセージ表示
define show_env_message
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		echo "[INFO] Dev Container 環境では $(1) は不要です。"; \
		echo "以下のコマンドでコンパイルできます:"; \
		echo "  make compile  # src 下の .tex ファイルをコンパイル"; \
		echo "  make watch   # ファイルの変更を監視してコンパイル"; \
	else \
		$(2); \
	fi
endef

# Docker 関連コマンド
build: ## Docker イメージをビルド
	$(call check_docker_env)
	docker compose build

up: ## コンテナを起動（バックグラウンド）
	$(call check_docker_env)
	docker compose up -d

down: ## コンテナを停止・削除
	$(call check_docker_env)
	docker compose down

exec: ## コンテナに接続
	$(call check_docker_env)
	docker compose exec latex bash

stop: ## コンテナを停止
	$(call check_docker_env)
	docker compose stop

logs: ## コンテナのログを表示
	$(call check_docker_env)
	docker compose logs -f latex

# 開発用コマンド
setup: ## 初回セットアップ (ビルド + 起動)
	$(call show_env_message,make setup による初回セットアップ,make build up && echo "環境構築を完了しました。以下のコマンドでコンパイルできます:" && echo "  make paper.pdf      # paper.tex をコンパイル" && echo "  make watch-chapters # chapters/ の変更を監視してコンパイル")

dev: ## 開発モード (起動 + chapters 監視コンパイル)
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		echo "[WARNING] Dev Container 環境では make up は不要です。make watch-chapters を実行します"; \
		make watch-chapters; \
	else \
		make up watch-chapters; \
	fi

restart: ## コンテナを再起動
	$(call check_docker_env)
	@make down up

rebuild: ## 完全に再ビルド
	$(call check_docker_env)
	@make down build up

# ファイル操作
open-pdf: ## 生成されたPDFを開く（Mac用）
	@if [ -f $(OUTPUT_PDF) ]; then \
		open $(OUTPUT_PDF); \
	else \
		echo "PDFファイルが見つかりません。先に make paper.pdf を実行してください。"; \
	fi
