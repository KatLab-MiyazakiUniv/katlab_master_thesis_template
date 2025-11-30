# KatLab 修士論文 LaTeX 執筆環境 (Docker)

このリポジトリは、Docker を使用した KatLab の修士論文執筆環境を提供するリポジトリである。

## 環境構築

### 1. Makefile を使用した環境構築

`make` コマンドが利用可能な環境では、すぐに以下の手順で環境を構築できる：

```bash
# 初回セットアップ（Docker イメージのビルドと起動）
make setup

# paper.tex をコンパイルし、PDF に変換
# その後、chapters/ 内のファイル変更を自動監視
make
```

`make` 実行後は、`chapters/` ディレクトリ内の .tex ファイルの変更を自動で監視し、変更があれば自動的に paper.pdf を再生成する。

生成された PDF ファイルは、プロジェクトのルートディレクトリに `paper.pdf` として出力される。

### 2. Dev Containers を使用した環境構築

VS Code の Dev Containers を使用して環境を構築することもできる：

1. VS Code に [Dev Containers](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) 拡張機能をインストールする。
2. このリポジトリを VS Code で開く。
3. コマンドパレット（`Cmd + Shift + P または Ctrl + Shift + P`）を開き、`Dev Containers: Rebuild and Reopen in Container` を選択する。もしくは、GUI 左下の青い >< から、`コンテナーで再度開く` -> `ワークスペースに構成を追加する` -> `` `Dockerfile` から`` -> 青い OK ボタン -> 青い OK ボタン の順で選択する。
4. コンテナ内で以下のコマンドを使用して作業を進める。

3 の後、環境構築に時間がかかり、表ではなにも進行していないように見えるが、実際は裏でダウンロードが進んでいるのでしばらく待つこと。
上記の手順により、Docker コンテナ内で `make` を実行可能となり、以下のコマンドで環境を構築できる：

```bash
# paper.tex をコンパイルし、PDF に変換
make
```

Dev Container 環境下では Docker 関連のコマンドの操作は不要。

`make` 実行後は、`chapters/` ディレクトリ内の .tex ファイルの変更を自動監視し、各 .tex ファイルの内容を paper.tex で結合させた PDF ファイルを、ルートディレクトリに `paper.pdf` として出力する。

## LaTeX 文書の作成とコンパイル

### 1. TeX ファイルの配置

.tex ファイルは `chapters/` ディレクトリに配置すること：

```
chapters/
├── 01-introduction.tex
├── 02-preparation.tex
├── 03-function.tex
├── 04-implementation.tex
├── 05-indication.tex
├── 06-discussion.tex
├── 07-conclusion.tex
└── 08-acknowledgments.tex
```

これらのファイルは、`paper.tex` で自動的に結合される。

### 2. コンパイル方法

```bash
# paper.tex をコンパイルし、paper.pdf を生成
make paper.pdf

# chapters/ 内のファイル変更を監視し、自動コンパイル
make watch-chapters

# デフォルト (paper.pdf を生成後、自動監視開始)
make
```

生成された PDF ファイルは、プロジェクトルートに `paper.pdf` として出力される。
`make` または `make watch-chapters` コマンド実行時、chapters 内の変更を自動で監視する。

## 利用可能な Make コマンド

### LaTeX 関連コマンド

| コマンド              | 説明                                           |
| --------------------- | ---------------------------------------------- |
| `make help`           | 利用可能なコマンド一覧を表示                   |
| `make paper.pdf`      | paper.tex をコンパイルし、paper.pdf を生成     |
| `make watch-chapters` | chapters/ 内のファイル変更を監視してコンパイル |
| `make clean`          | LaTeX 中間ファイルを削除                       |
| `make clean-all`      | すべての LaTeX 生成ファイルを削除              |
| `make open-pdf`       | 生成された PDF を開く (Mac 用)                 |
| `make kill-make`      | 既存の make プロセスを強制終了                 |

### Docker 関連コマンド

| コマンド       | 説明                                        |
| -------------- | ------------------------------------------- |
| `make setup`   | 初回セットアップ (ビルド + 起動)            |
| `make build`   | Docker イメージをビルド                     |
| `make up`      | コンテナを起動                              |
| `make down`    | コンテナを停止・削除                        |
| `make exec`    | コンテナに接続                              |
| `make stop`    | コンテナを停止                              |
| `make logs`    | コンテナのログを表示                        |
| `make restart` | コンテナを再起動                            |
| `make rebuild` | 完全に再ビルド                              |
| `make dev`     | 開発モード (起動 + chapters 監視コンパイル) |

## ディレクトリ構成

```
katlab_master_thesis_template/
├── Dockerfile          # Docker 環境定義
├── compose.yaml        # Docker Compose 設定
├── Makefile            # ビルドタスク定義
├── .latexmkrc          # LaTeXmk 設定
├── .gitignore          # Git 無視ファイル設定
├── README.md           # このファイル
├── paper.tex           # メイン論文ファイル
├── paper.pdf           # 生成された PDF (コンパイル後)
├── paper.bib           # 参考文献データベース
├── outline.tex         # 論文のアウトライン
├── languages.sty       # 言語設定ファイル
├── build/              # コンパイル中間ファイル
│   └── *.aux, *.dvi, *.log など
├── chapters/           # 各章の TeX ソースファイル
│   ├── 01-introduction.tex
│   ├── 02-preparation.tex
│   ├── 03-function.tex
│   ├── 04-implementation.tex
│   ├── 05-indication.tex
│   ├── 06-discussion.tex
│   ├── 07-conclusion.tex
│   └── 08-acknowledgments.tex
├── images/             # 画像ファイル
│   └── *.png, *.jpg など
└── packages/           # カスタム LaTeX パッケージ
    └── *.sty
```

## 論文の構成

`paper.tex` は以下の構成で章を結合する：

1. はじめに (`chapters/01-introduction.tex`)
2. 研究の準備 (`chapters/02-preparation.tex`)
3. 機能 (`chapters/03-function.tex`)
4. 実装 (`chapters/04-implementation.tex`)
5. 適用例 (`chapters/05-indication.tex`)
6. 考察 (`chapters/06-discussion.tex`)
7. おわりに (`chapters/07-conclusion.tex`)
8. 謝辞 (`chapters/08-acknowledgments.tex`)

## 使用できる TeXLive パッケージ

このテンプレートでは、以下のパッケージが利用可能：

- **latexmk**: 自動コンパイルツール
- **jsbook**: 日本語書籍クラス
- **graphicx**: 画像挿入
- **hyperref**: ハイパーリンク機能
- **listings**: ソースコード挿入
- その他、TeX Live に含まれる標準パッケージ

## 不具合対処

### 1. ログファイルの確認

```bash
ls -l build/*.log
```

### 2. クリーンアップして再コンパイル

```bash
make clean-all  # すべての生成ファイルを削除
make paper.pdf  # 再コンパイル
```

### 3. Docker 環境の再構築

```bash
make rebuild    # コンテナの完全な再構築
```

### 4. service "latex" is not running の対処

```bash
service "latex" is not running
make: *** [paper.pdf] Error 1
```

**原因**
Docker compose 環境で動作しようとしているものの、コンテナが起動していない。

**解決策**
以下のコマンドでコンテナを起動する。

```bash
make up
```

そもそもビルドをしていない、初回設定をしていない場合は、`make setup` を実行する。

### 5. コンパイルエラーが発生する場合

- `build/` ディレクトリ内の `.log` ファイルを確認
- LaTeX のエラーメッセージを確認
- 必要に応じて `make clean-all` で中間ファイルをすべて削除してから再コンパイル
