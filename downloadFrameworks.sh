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

