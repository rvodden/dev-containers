#!/usr/bin/env bash

set -euo pipefail

# Auto-Get the latest commit sha via command line.
get_latest_release() {
    TAG=$(wget -q --output-document - "https://api.github.com/repos/${1}/releases/latest" | # Get latest release from GitHub API
          grep '"tag_name":'           | # Get tag line
          sed -E 's/.*"([^"]+)".*/\1/' ) # Pluck JSON value

    TAG_DATA=$(wget -q --output-document - "https://api.github.com/repos/${1}/git/ref/tags/${TAG}")

    SHA=$(echo "${TAG_DATA}"           | # Get latest release from GitHub API
          grep '"sha":'                | # Get tag line
          sed -E 's/.*"([^"]+)".*/\1/' ) # Pluck JSON value

    SHA_TYPE=$(echo "${TAG_DATA}"           | # Get latest release from GitHub API
          grep '"type":'                    | # Get tag line
          sed -E 's/.*"([^"]+)".*/\1/'      ) # Pluck JSON value

    if [ "${SHA_TYPE}" != "commit" ]; then
        COMBO_SHA=$(curl -s "https://api.github.com/repos/${1}/git/tags/${sha}" | # Get latest release from GitHub API
              grep '"sha":'                                                     | # Get tag line
              sed -E 's/.*"([^"]+)".*/\1/'                                      ) # Pluck JSON value

        # Remove the tag sha, leaving only the commit sha;
        # this won't work if there are ever more than 2 sha,
        # and use xargs to remove whitespace/newline.
        SHA=$(echo "${COMBO_SHA}" | sed -E "s/${SHA}//" | xargs)
    fi

    printf "${SHA}"
}

ARCH="x64"
U_NAME=$(uname -m)

if [ "${U_NAME}" = "aarch64" ]; then
    ARCH="arm64"
fi

ARCHIVE="vscode-server-linux-${ARCH}.tar.gz"
OWNER='microsoft'
REPO='vscode'
COMMIT_SHA=$(get_latest_release "${OWNER}/${REPO}")

if [ -n "${COMMIT_SHA}" ]; then
    echo "will attempt to download VS Code Server version = '${COMMIT_SHA}'"

    # Download VS Code Server tarball to tmp directory.
    wget -q "https://update.code.visualstudio.com/commit:${COMMIT_SHA}/server-linux-${ARCH}/stable" --output-document "/tmp/${ARCHIVE}"

    # Make the parent directory where the server should live.
    # NOTE: Ensure VS Code will have read/write access; namely the user running VScode or container user.
    mkdir -vp "/root/.vscode-server"

    # Extract the tarball to the right location.
    tar --no-same-owner -xzv --strip-components=1 -C "/root/.vscode-server" -f "/tmp/${ARCHIVE}"
else
    echo "could not pre install vscode server"
fi