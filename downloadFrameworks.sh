#!/bin/sh

set -eu

# Apple pre-compiled XcFrameworks, defined in xcfs/Package.swift, with checksum control:
swift run --package-path xcfs

# Build BeeWare's Python Apple Support frameworks locally instead of downloading
# a pre-packaged archive. Developers can override the defaults via the following
# environment variables:
#   * PYTHON_SUPPORT_DIR: checkout directory (default: Python-Apple-support)
#   * PYTHON_SUPPORT_REPO: git URL for the support repo
#   * PYTHON_SUPPORT_BRANCH: branch or tag to checkout
#   * PYTHON_SUPPORT_BUILD_ARGS: optional arguments passed to build.sh
PYTHON_SUPPORT_DIR=${PYTHON_SUPPORT_DIR:-"Python-Apple-support"}
PYTHON_SUPPORT_REPO=${PYTHON_SUPPORT_REPO:-"https://github.com/beeware/Python-Apple-support.git"}
PYTHON_SUPPORT_BRANCH=${PYTHON_SUPPORT_BRANCH:-"main"}

if [ ! -d "$PYTHON_SUPPORT_DIR/.git" ]; then
    echo "Cloning BeeWare's Python Apple Support repository (${PYTHON_SUPPORT_REPO})"
    rm -rf "$PYTHON_SUPPORT_DIR"
    git clone --branch "$PYTHON_SUPPORT_BRANCH" "$PYTHON_SUPPORT_REPO" "$PYTHON_SUPPORT_DIR"
else
    echo "Updating BeeWare's Python Apple Support checkout in $PYTHON_SUPPORT_DIR"
    git -C "$PYTHON_SUPPORT_DIR" fetch origin "$PYTHON_SUPPORT_BRANCH"
    git -C "$PYTHON_SUPPORT_DIR" checkout "$PYTHON_SUPPORT_BRANCH"
    git -C "$PYTHON_SUPPORT_DIR" pull --ff-only origin "$PYTHON_SUPPORT_BRANCH"
fi

echo "Building Python frameworks using BeeWare's tooling"
(
    cd "$PYTHON_SUPPORT_DIR"
    sh ./build.sh ${PYTHON_SUPPORT_BUILD_ARGS:-}
)

echo "Locating built Python artifacts"
ARTIFACT_ROOT=$PYTHON_SUPPORT_DIR

ensure_install_tree() {
    # If build.sh already produced install trees, keep them.
    if [ -d "$ARTIFACT_ROOT/Library" ] && [ -d "$ARTIFACT_ROOT/install_mini/Library" ]; then
        echo "Found existing BeeWare install trees"
        return
    fi

    # Try to unzip the latest iOS support archive emitted by build.sh.
    SUPPORT_ARCHIVE=$(find "$ARTIFACT_ROOT" -maxdepth 4 -type f \
        \( -name "Python-*-iOS-support*.tar.gz" -o -name "Python-*-iOS-support*.zip" -o -name "Python-*-iOS-support*.b3" \) \
        | sort -r | head -n1)

    if [ -z "$SUPPORT_ARCHIVE" ]; then
        echo "No iOS support archive found; ensure build.sh produced install or install_mini outputs." >&2
        exit 1
    fi

    echo "Extracting $SUPPORT_ARCHIVE"
    case "$SUPPORT_ARCHIVE" in
        *.zip|*.b3)
            python3 - <<PY
import zipfile
from pathlib import Path

archive = Path("$SUPPORT_ARCHIVE")
with zipfile.ZipFile(archive) as zf:
    zf.extractall(archive.parent)
PY
            ;;
        *)
            tar -xzf "$SUPPORT_ARCHIVE" -C "$(dirname "$SUPPORT_ARCHIVE")"
            ;;
    esac

    # If the archive nested everything under a single folder, flatten it to the support root.
    NESTED_DIR=$(find "$ARTIFACT_ROOT" -maxdepth 1 -type d -name "Python-*-iOS-support*" | head -n1)
    if [ -n "$NESTED_DIR" ]; then
        echo "Flattening extracted payload from $(basename "$NESTED_DIR")"
        (cd "$NESTED_DIR" && find . -maxdepth 1 -mindepth 1 -exec mv "{}" "$ARTIFACT_ROOT" \;)
        rmdir "$NESTED_DIR"
    fi

    if [ ! -d "$ARTIFACT_ROOT/Library" ] || [ ! -d "$ARTIFACT_ROOT/install_mini/Library" ]; then
        echo "Expected Library and install_mini trees were not found after extraction." >&2
        exit 1
    fi
}

ensure_install_tree

echo "BeeWare artifacts are ready under $ARTIFACT_ROOT (run updatePythonFiles.sh to sync Resources)"

