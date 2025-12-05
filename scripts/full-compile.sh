#!/bin/bash
set -euo pipefail

# Full compilation script for LaTeX + BibTeX (paper.tex)
# Usage: ./full-compile.sh [--retry]
#
# This script performs a complete LaTeX compilation including:
# - Multiple LaTeX passes for cross-references
# - pBibTeX for bibliography processing
# - DVI to PDF conversion
# - Automatic retry with cleanup on failure

# Logging functions
log_info() {
    echo "[INFO] $*"
}

log_warn() {
    echo "[WARN] $*"
}

log_error() {
    echo "[ERROR] $*" >&2
}

# Cleanup function
cleanup_on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "Compilation failed with exit code $exit_code"
    fi
    exit $exit_code
}

trap cleanup_on_exit EXIT

# Configuration
TEX_BASE="paper"
MAIN_TEX="${TEX_BASE}.tex"
RETRY_MODE=false

# Parse arguments
if [[ $# -gt 0 && "$1" == "--retry" ]]; then
    RETRY_MODE=true
fi

# Determine workspace directory
if [[ -f /.dockerenv ]]; then
    WORKSPACE="/workspace"
else
    WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fi

cd "$WORKSPACE"

log_info "=== Full compilation of ${MAIN_TEX} ==="

# Step 1: Clean all intermediate files if retry mode
if [[ "$RETRY_MODE" == true ]]; then
    log_info "Step 1: Cleaning all files for retry..."
    latexmk -C "$MAIN_TEX"
    rm -rf build/*
fi

# Ensure build directory exists
mkdir -p build

# Step 2: First LaTeX compilation
log_info "Step 2: First LaTeX compilation..."
if ! LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 uplatex -output-directory=build -interaction=nonstopmode "$MAIN_TEX" > /dev/null 2>&1; then
    log_warn "First LaTeX compilation had warnings/errors (continuing)"
fi

# Check for cross-references and citations
check_references() {
    local aux_file="build/${TEX_BASE}.aux"
    local log_file="build/${TEX_BASE}.log"

    # Check for undefined references
    if [[ -f "$log_file" ]] && grep -q "LaTeX Warning.*undefined" "$log_file"; then
        return 1  # References still undefined
    fi

    # Check for citation warnings
    if [[ -f "$log_file" ]] && grep -q "LaTeX Warning.*Citation" "$log_file"; then
        return 1  # Citations still undefined
    fi

    # Check for "Rerun to get cross-references right"
    if [[ -f "$log_file" ]] && grep -q "Rerun to get cross-references right" "$log_file"; then
        return 1  # Need to rerun
    fi

    return 0  # All references resolved
}

# Step 3: Check if bibliography is needed and handle multiple compilations
# Wait a moment for aux file to be fully written
sleep 1
if grep -q "\\\\bibdata\\|\\\\citation" "build/${TEX_BASE}.aux" 2>/dev/null; then
    log_info "Step 3: Running pBibTeX..."
    cd build

    # Copy necessary files from root
    cp ../*.bib . 2>/dev/null || log_warn "No .bib files found"
    cp ../*.bst . 2>/dev/null || log_warn "No .bst files found"

    # Run pBibTeX with verbose output for debugging
    if pbibtex "$TEX_BASE"; then
        log_info "pBibTeX completed successfully"
    else
        log_warn "pBibTeX failed, continuing without bibliography"
    fi

    cd "$WORKSPACE"
else
    log_info "No bibliography found, skipping pBibTeX"
fi

# Step 4-N: Compile until all references are resolved
log_info "Step 4: Compiling until all references are resolved..."
compile_count=2
max_compiles=10

while [[ $compile_count -le $max_compiles ]]; do
    log_info "LaTeX compilation #${compile_count}..."
    if ! LANG=ja_JP.UTF-8 LC_ALL=ja_JP.UTF-8 uplatex -output-directory=build -interaction=nonstopmode "$MAIN_TEX" > /dev/null 2>&1; then
        log_warn "LaTeX compilation #${compile_count} had warnings/errors (continuing)"
    fi

    # Check if references are resolved
    if check_references; then
        log_info "All references resolved after ${compile_count} compilations"
        break
    elif [[ $compile_count -eq $max_compiles ]]; then
        log_warn "Reached maximum compilations ($max_compiles). Some references may still be unresolved."
        break
    else
        log_info "References still unresolved, continuing..."
        ((compile_count++))
    fi
done

# Step 5: Copy images to build directory
log_info "Step 5: Copying images to build directory..."
cd "$WORKSPACE/build"
if [[ -d "../images" ]]; then
    cp -r ../images . 2>/dev/null || log_warn "Failed to copy images directory"
    log_info "Images copied successfully"
else
    log_warn "No images directory found"
fi

# Step 6: Generate PDF
log_info "Step 6: Generating PDF..."
if [[ -f "${TEX_BASE}.dvi" ]]; then
    if dvipdfmx "${TEX_BASE}.dvi" 2>/dev/null || [[ -f "${TEX_BASE}.pdf" ]]; then
        log_info "PDF generation successful"

        # Copy PDF to root directory
        if cp "${TEX_BASE}.pdf" ../ 2>/dev/null; then
            log_info "=== Compilation completed successfully ==="
            log_info "PDF: ${TEX_BASE}.pdf"
            ls -la "../${TEX_BASE}.pdf" 2>/dev/null || log_warn "PDF file not found in root directory"
        else
            log_error "Failed to copy PDF to root directory"
            exit 1
        fi
    else
        log_error "DVI to PDF conversion failed"
        exit 1
    fi
else
    log_error "DVI file not generated"
    exit 1
fi
