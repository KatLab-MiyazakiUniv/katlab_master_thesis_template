# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a Japanese LaTeX thesis template for Miyazaki University (宮崎大学) KatLab master's theses. The environment uses Docker and supports both Docker Compose and VS Code Dev Containers workflows. Documents are written in Japanese using uplatex and compiled via latexmk.

## Build and Compilation Commands

### Initial Setup

```bash
# Docker Compose workflow (first time)
make setup

# Dev Containers workflow
# No setup needed - just run make
```

### Core Commands

```bash
# Compile paper.tex and watch for changes in chapters/ (most common)
make

# Compile paper.tex once without watching
make paper.pdf

# Watch chapters/ for changes and auto-compile
make watch-chapters

# Clean intermediate files
make clean

# Clean all generated files including PDFs
make clean-all

# Open the generated PDF (macOS only)
make open-pdf
```

### Docker Commands (Docker Compose only, NOT for Dev Containers)

```bash
make build    # Build Docker image
make up       # Start container
make down     # Stop and remove container
make exec     # Connect to container
make restart  # Restart container
make rebuild  # Complete rebuild
```

### Template Synchronization

This repository serves as a template. Repositories created from this template can sync updates using:

```bash
bash scripts/sync-template.sh
```

The script:
1. Fetches latest changes from the template repository
2. Shows differences between template and current repo
3. Offers merge/rebase options to incorporate updates
4. Handles conflicts if they occur

**Manual sync method:**
```bash
git remote add template https://github.com/KatLab-MiyazakiUniv/katlab_master_thesis_template.git
git fetch template
git merge template/main --allow-unrelated-histories
```

## Architecture

### LaTeX Compilation Pipeline

- **Compiler**: uplatex (upLaTeX - Unicode-compatible Japanese LaTeX)
- **DVI to PDF**: dvipdfmx
- **Build tool**: latexmk (configured in `.latexmkrc`)
- **Bibliography**: pbibtex with junsrt style
- **Watch mechanism**: Uses fswatch (macOS), inotifywait (Linux), or polling fallback

### Directory Structure

```
paper.tex               # Main thesis file (combines all chapters)
paper.bib               # Bibliography database
outline.tex             # Thesis outline
languages.sty           # Language/code highlighting settings
chapters/               # Individual chapter .tex files
  01-introduction.tex
  02-preparation.tex
  03-function.tex
  04-implementation.tex
  05-indication.tex
  06-discussion.tex
  07-conclusion.tex
  08-acknowledgments.tex
packages/               # Custom LaTeX style files
  miyazaki-u-paper.sty  # University thesis style (by Prof. Katayama)
  jlisting.sty          # Japanese listings support
  listings.sty          # Code listing support
images/                 # Image files referenced in thesis
build/                  # Compilation artifacts (.aux, .dvi, .log, etc.)
scripts/                # Utility scripts
  watch.sh              # File watching script (used by Makefile)
  sync-template.sh      # Template synchronization script
```

### Execution Environment Detection

The Makefile automatically detects whether running in:
- **Dev Container** (checks `/.dockerenv` + `.devcontainer/devcontainer.json`)
- **Docker Compose** (requires explicit container execution)
- **Host machine** (direct execution)

Commands adjust automatically based on the detected environment.

### LaTeX Document Structure

`paper.tex` is the main file that:
1. Uses `jsbook` document class (Japanese book style)
2. Includes various packages from `packages/` directory
3. Inputs all chapter files from `chapters/` via `\input{}`
4. Defines thesis metadata via custom commands:
   - `\degree{m}` - Master's thesis (use 'g' for graduate/bachelor)
   - `\title{}`, `\author{}`, `\nendo{}`, `\major{}`
5. Uses `miyazaki-u-paper.sty` for university-specific formatting

### Code Highlighting Support

The `languages.sty` file provides syntax highlighting configurations for:
- Java (default)
- Kotlin (custom lstlisting definition)
- Swift (custom lstlisting definition)

## Important Notes

- All chapter files must be placed in `chapters/` directory
- Chapter files are automatically included by `paper.tex` in numerical order
- The build output is always `paper.pdf` in the project root
- Intermediate files are stored in `build/` directory
- The environment uses UTF-8 encoding with Japanese locale (ja_JP.UTF-8)
- When editing LaTeX: preserve indentation and line structure for proper compilation
- The Docker image is based on `paperist/texlive-ja:latest` with additional packages (algorithms, algorithmicx)

## Template Maintenance

### PID File Management

The project uses PID files to manage watch processes and prevent multiple simultaneous instances:

- `.watch.pid` - Tracks the watch.sh process (created by scripts/watch.sh)
- `.make.pid` - Reserved for future use (currently unused)

Both files are:
- Automatically created/deleted by their respective processes
- Excluded from version control (.gitignore)
- Used to ensure only one watch process runs at a time

### Process Management

When `make` is executed:
1. `kill_watch_processes` checks for existing `.watch.pid`
2. If found, terminates the old watch process gracefully
3. New watch process starts and writes its PID to `.watch.pid`
4. On exit (Ctrl+C), the PID file is automatically cleaned up

This prevents "Terminated" errors and ensures clean single-process operation.
