.PHONY: help build up down exec clean compile watch watch-chapters pdf stop logs kill-make

# TeXファイルのリストを取得（サブディレクトリも含む）
TEX_FILES := $(shell if [ -d src ]; then find src -name "*.tex" -type f; fi)
PDF_FILES := $(patsubst src/%.tex,pdf/%.pdf,$(TEX_FILES))

# chaptersディレクトリ内の.texファイルのリスト
CHAPTER_TEX_FILES := $(shell find chapters -name "*.tex" -type f)

# プロセス管理関数
define kill_existing_make_processes
	@echo "既存のmakeプロセスをチェック中..."
	@if [ -f .make.pid ]; then \
		old_pid=$$(cat .make.pid); \
		if kill -0 $$old_pid 2>/dev/null; then \
			echo "既存のmakeプロセス(PID: $$old_pid)を終了中..."; \
			kill $$old_pid 2>/dev/null || true; \
			sleep 1; \
			kill -9 $$old_pid 2>/dev/null || true; \
			echo "既存のプロセスを終了しました"; \
		fi; \
		rm -f .make.pid; \
	fi
	@$(DOCKER_PREFIX) pkill -f "watch.sh" 2>/dev/null || echo "Docker内のwatchプロセスを終了しました"
	@echo $$$$ > .make.pid
endef

# 実行環境の判定
IN_DEVCONTAINER := $(shell test -f /.dockerenv && test -f /workspace/.devcontainer/devcontainer.json && echo 1 || echo 0)

# 環境に応じたコマンドの定義
ifeq ($(IN_DEVCONTAINER),1)
    # Dev Container 内での実行コマンド
    DOCKER_PREFIX =
    CD_PREFIX = cd /workspace &&
else
    # Docker Compose 経由での実行コマンド
    DOCKER_PREFIX = docker compose exec -T latex
    CD_PREFIX = bash -c cd /workspace &&
endif

# 共通のコマンドを定義
LATEX_CMD       = $(DOCKER_PREFIX) $(CD_PREFIX) TEXINPUTS=./src//: LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 latexmk -pdfdvi
LATEX_CLEAN     = $(DOCKER_PREFIX) $(CD_PREFIX) latexmk -c
LATEX_CLEAN_ALL = $(DOCKER_PREFIX) $(CD_PREFIX) latexmk -C
CP_CMD          = $(DOCKER_PREFIX) $(CD_PREFIX) cp
RM_CMD          = $(DOCKER_PREFIX) $(CD_PREFIX) rm -rf

# ファイル監視スクリプト（全環境対応）
WATCH_CMD       = $(DOCKER_PREFIX) bash -c "sed -i 's/\r$$//' /workspace/scripts/watch.sh && bash /workspace/scripts/watch.sh"

# paper.tex 用の latexmk コマンド
PAPER_LATEXMK_CMD = TEXINPUTS=./chapters//:./packages//: LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 PATH=/usr/local/bin/texlive:$$PATH latexmk -pdfdvi -jobname=paper -output-directory=build -interaction=nonstopmode paper.tex

# paper.texをPDFにコンパイル
paper.pdf: paper.tex $(CHAPTER_TEX_FILES)
	@mkdir -p build
	@echo "paper.texをコンパイル中..."
ifeq ($(IN_DEVCONTAINER),1)
	@$(PAPER_LATEXMK_CMD)
else
	@$(DOCKER_PREFIX) bash -lc "cd /workspace && $(PAPER_LATEXMK_CMD)"
endif
	@if [ ! -f build/paper.pdf ]; then \
		echo "[ERROR] PDFの作成に失敗しました。build/paper.pdf が見つかりません。"; \
		exit 1; \
	fi
	@cp build/paper.pdf paper.pdf
	@echo "PDFを作成しました: paper.pdf"

# デフォルトターゲット - 初回コンパイル後、自動監視開始
all: ## paper.texをPDFに変換し、chapters内のファイル変更を監視
	$(call kill_existing_make_processes)
	@$(MAKE) paper.pdf
	@$(MAKE) watch-chapters

# 初回コンパイル（監視なし）
compile-all: $(PDF_FILES) ## すべての TeX ファイルを PDF に変換（監視なし）
	@if [ -n "$(TEX_FILES)" ]; then \
		echo "初回コンパイル完了。"; \
	else \
		echo "[WARNING] src/ ディレクトリに .tex ファイルが見つかりません。"; \
		exit 1; \
	fi

# デフォルト：paper.texをコンパイル後、chapters内のファイル変更を監視
default: ## paper.texをコンパイル後、chapters内のファイル変更を監視
	$(call kill_existing_make_processes)
	@$(MAKE) paper.pdf
	@$(MAKE) watch-chapters

.DEFAULT_GOAL := default

help: ## ヘルプを表示
	@echo "利用可能なコマンド:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

kill-make: ## 既存のmakeプロセスを強制終了
	$(call kill_existing_make_processes)

# ファイル別の PDF ビルドルール
pdf/%.pdf: src/%.tex
	@mkdir -p pdf build $(dir $@)
	@echo "ファイルをコンパイル: $<"
	@$(DOCKER_PREFIX) bash -c "cd /workspace && TEXINPUTS=./src//: latexmk -pdfdvi $<" || true
	@$(CP_CMD) build/$(notdir $(basename $<)).pdf $@ || true

# LaTeX 関連コマンド
compile: ## src 下の .tex ファイルをコンパイル
	@mkdir -p pdf build
	@for tex in $(TEX_FILES); do \
		echo "コンパイル: $$tex"; \
		rel_path=$$(echo "$$tex" | sed 's|^src/||'); \
		pdf_dir=pdf/$$(dirname "$$rel_path"); \
		mkdir -p "$$pdf_dir"; \
		$(DOCKER_PREFIX) bash -c "cd /workspace && TEXINPUTS=./src//: latexmk -pdfdvi $$tex" || true; \
		pdf_name=$$(echo "$$rel_path" | sed 's/\.tex$$/\.pdf/'); \
		$(CP_CMD) build/$$(basename $${tex%.tex}).pdf "pdf/$$pdf_name" || true; \
	done
	@echo "コンパイル完了"

watch: ## ファイル変更を監視してコンパイル（全環境対応）
	$(call kill_existing_make_processes)
	@mkdir -p pdf build
	@echo "watching: src/**/*.tex (auto-detecting best method for your environment)"
	@trap 'rm -f .make.pid; exit' INT TERM; $(WATCH_CMD)

# chapters内のファイル変更を監視してpaper.texをコンパイル
watch-chapters: ## chapters内のファイル変更を監視してpaper.texをコンパイル
	$(call kill_existing_make_processes)
	@mkdir -p build
	@echo "watching: chapters/**/*.tex, paper.tex"
	@trap 'rm -f .make.pid; exit' INT TERM; \
	if command -v fswatch > /dev/null 2>&1; then \
		fswatch -o chapters paper.tex | while read; do \
			echo "ファイル変更を検知しました。コンパイルを開始します..."; \
			$(MAKE) paper.pdf || echo "[ERROR] コンパイルに失敗しました"; \
		done; \
	elif command -v inotifywait > /dev/null 2>&1; then \
		while inotifywait -e modify,create,delete -r chapters paper.tex 2>/dev/null; do \
			echo "ファイル変更を検知しました。コンパイルを開始します..."; \
			$(MAKE) paper.pdf || echo "[ERROR] コンパイルに失敗しました"; \
		done; \
	else \
		last_time=$$(find chapters paper.tex -type f -name "*.tex" 2>/dev/null | \
			xargs stat -f "%m" 2>/dev/null | sort -n | tail -1 || \
			find chapters paper.tex -type f -name "*.tex" 2>/dev/null | \
			xargs stat -c "%Y" 2>/dev/null | sort -n | tail -1 || echo 0); \
		while true; do \
			current_time=$$(find chapters paper.tex -type f -name "*.tex" 2>/dev/null | \
				xargs stat -f "%m" 2>/dev/null | sort -n | tail -1 || \
				find chapters paper.tex -type f -name "*.tex" 2>/dev/null | \
				xargs stat -c "%Y" 2>/dev/null | sort -n | tail -1 || echo 0); \
			if [ "$$current_time" != "$$last_time" ]; then \
				echo "ファイル変更を検知しました。コンパイルを開始します..."; \
				$(MAKE) paper.pdf || echo "[ERROR] コンパイルに失敗しました"; \
				last_time=$$current_time; \
			fi; \
			sleep 1; \
		done; \
	fi

clean: ## LaTeX 中間ファイルを削除
	@for tex in $(TEX_FILES); do \
		echo "中間ファイル削除中: $$tex"; \
		$(LATEX_CLEAN) $$tex; \
	done
	@if [ -f paper.tex ]; then \
		echo "paper.texの中間ファイルを削除中..."; \
		$(DOCKER_PREFIX) bash -c "cd /workspace && latexmk -c paper.tex" || \
		bash -c "cd /workspace && latexmk -c paper.tex" || true; \
	fi
	$(RM_CMD) pdf/* paper.pdf

clean-all: ## すべての LaTeX 生成ファイルを削除
	@for tex in $(TEX_FILES); do \
		echo "生成ファイル完全削除中: $$tex"; \
		$(LATEX_CLEAN_ALL) $$tex; \
	done
	@if [ -f paper.tex ]; then \
		echo "paper.texの生成ファイルを完全削除中..."; \
		$(DOCKER_PREFIX) bash -c "cd /workspace && latexmk -C paper.tex" || \
		bash -c "cd /workspace && latexmk -C paper.tex" || true; \
	fi
	$(RM_CMD) pdf/* build/* paper.pdf

# Docker 関連コマンド実行時の実行環境チェック
# devcontainer 下で docker コマンドを実行できないので、その場合は警告文を表示して終了する
check_docker_cmd = @if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
	echo "[ERROR] Dev Container 環境では Docker 関連コマンドは使用できません"; \
	exit 1; \
fi

# Docker 関連コマンド
build: ## Docker イメージをビルド
	$(check_docker_cmd)
	docker compose build

up: ## コンテナを起動（バックグラウンド）
	$(check_docker_cmd)
	docker compose up -d

down: ## コンテナを停止・削除
	$(check_docker_cmd)
	docker compose down

exec: ## コンテナに接続
	$(check_docker_cmd)
	docker compose exec latex bash

stop: ## コンテナを停止
	$(check_docker_cmd)
	docker compose stop

logs: ## コンテナのログを表示
	$(check_docker_cmd)
	docker compose logs -f latex

# 開発用コマンド
setup: ## 初回セットアップ (ビルド + 起動)
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		echo "[INFO] Dev Container 環境では make setup による初回セットアップは不要です。"; \
		echo "以下のコマンドでコンパイルできます:"; \
		echo "  make  # paper.texをコンパイルしてchapters内のファイル変更を監視"; \
		echo "  make watch-chapters  # chapters内のファイル変更を監視してコンパイル"; \
	else \
		make build up; \
		echo "環境構築を完了しました。以下のコマンドでコンパイルできます:"; \
		echo "  make  # paper.texをコンパイルしてchapters内のファイル変更を監視"; \
		echo "  make watch-chapters  # chapters内のファイル変更を監視してコンパイル"; \
	fi

dev: ## 開発モード (起動 + 監視コンパイル)
	@if [ "$(IN_DEVCONTAINER)" = "1" ]; then \
		echo "[WARNING] Dev Container 環境では make up は不要です。make watch-chapters を実行します"; \
		make watch-chapters; \
	else \
		make up watch-chapters; \
	fi

restart: ## コンテナを再起動
	$(check_docker_cmd)
	@make down up

rebuild: ## 完全に再ビルド
	$(check_docker_cmd)
	@make down build up

# ファイル操作
open-pdf: ## 生成されたPDFを開く（Mac用）
	@if [ -f paper.pdf ]; then \
		open paper.pdf; \
	elif [ -f build/sample.pdf ]; then \
		open build/sample.pdf; \
	else \
		echo "PDFファイルが見つかりません。先に make を実行してください。"; \
	fi
