#!/bin/sh
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
#  Helper: build https url with token if private repo
# ──────────────────────────────────────────────────────────────────────────────
prepare_git_url() {
    local url="$1"

    # Already has https://user:token@ ?
    case "$url" in
        https://*@github.com*) echo "$url"; return ;;
    esac

    # Has token → inject it
    if [ -n "${GIT_TOKEN:-}" ]; then
        local auth_part
        if [ -n "${GIT_USER:-}" ]; then
            auth_part="${GIT_USER}:${GIT_TOKEN}"
        else
            # GitHub allows just token as username (works since ~2021)
            auth_part="git:${GIT_TOKEN}"
        fi

        url="${url/https:\/\//https:\/\/${auth_part}@}"
    fi

    echo "$url"
}

# ──────────────────────────────────────────────────────────────────────────────
main() {
    if [ -z "${GIT_REPO_URL:-}" ]; then
        echo "✘ GIT_REPO_URL is required" >&2
        exit 1
    fi

    if [ -z "${START_CMD:-}" ]; then
        echo "✘ START_CMD is required" >&2
        exit 1
    fi

    # Prepare authenticated URL if needed
    CLONE_URL=$(prepare_git_url "$GIT_REPO_URL")

    # Check if /app exists and matches remote
    if [ -d "/app/.git" ]; then
        echo "→ /app exists, checking remote..."
        cd /app || exit 1
        CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

        # Strip authentication from both URLs for comparison
        CURRENT_REMOTE_CLEAN=$(echo "$CURRENT_REMOTE" | sed 's|https://[^@]*@|https://|')
        EXPECTED_REMOTE_CLEAN=$(echo "$GIT_REPO_URL" | sed 's|https://[^@]*@|https://|')

        if [ "$CURRENT_REMOTE_CLEAN" = "$EXPECTED_REMOTE_CLEAN" ]; then
            echo "→ Remote matches. Syncing..."
            git status
            git pull
        else
            echo "→ Remote mismatch (Found: $CURRENT_REMOTE_CLEAN, Expected: $EXPECTED_REMOTE_CLEAN). Re-cloning..."
            cd / || exit 1
            rm -rf /app
        fi
    elif [ -d "/app" ]; then
        # Exists but not a git repo -> wipe it
        echo "→ /app exists but is not a git repo. Cleaning up..."
        rm -rf /app
    fi

    # Clone if /app is missing (was not there or was deleted)
    if [ ! -d "/app" ]; then
        echo "→ Cloning $(basename "${GIT_REPO_URL}") ..."
        git clone --depth="${GIT_CLONE_DEPTH:-1}" "$CLONE_URL" /app
        echo "→ Repository cloned into /app"
    fi

    cd /app || exit 1

    # ────────────────────────────────────────────────
# Install extra Alpine packages from env (if any)
# ────────────────────────────────────────────────
if [ -n "${APK_PACKAGES:-}" ]; then
    echo "→ Installing extra Alpine packages: ${APK_PACKAGES}"
    apk update --quiet
    # shellcheck disable=SC2086   # we want word splitting here on purpose
    apk add --no-cache ${APK_PACKAGES}
    echo "→ Extra packages installed"
else
    echo "→ No extra APK_PACKAGES requested"
fi

# Now safe to run npm ci (some packages provide build tools sharp needs, etc.)
echo "→ Running npm ci ..."
npm ci --prefer-offline --no-audit --no-fund --quiet || {
    echo "npm ci failed – retrying without --quiet for better logs:"
    npm ci --prefer-offline --no-audit --no-fund
    exit 1
}

    # Optional: you can add here composer install / bundle install / pnpm install etc
    # if you want – but better to keep this image generic

    echo "→ Executing: ${START_CMD}"
    echo "───────────────────────────────────────────────"

    # shellcheck disable=SC2086  # we want word splitting here
    exec sh -c "${START_CMD}"
}

main "$@"