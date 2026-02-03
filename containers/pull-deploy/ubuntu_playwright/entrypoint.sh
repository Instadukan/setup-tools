#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────────────────────
#  Helper: build https url with token if private repo
# ──────────────────────────────────────────────────────────────────────────────
prepare_git_url() {
    local url="$1"

    case "$url" in
        https://*@github.com*) echo "$url"; return ;;
    esac

    if [ -n "${GIT_TOKEN:-}" ]; then
        local auth_part
        if [ -n "${GIT_USER:-}" ]; then
            auth_part="${GIT_USER}:${GIT_TOKEN}"
        else
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

    CLONE_URL=$(prepare_git_url "$GIT_REPO_URL")

    if [ -d "/app/.git" ]; then
        echo "→ /app exists, checking remote..."
        cd /app || exit 1
        CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

        CURRENT_REMOTE_CLEAN=$(echo "$CURRENT_REMOTE" | sed 's|https://[^@]*@|https://|')
        EXPECTED_REMOTE_CLEAN=$(echo "$GIT_REPO_URL"   | sed 's|https://[^@]*@|https://|')

        if [ "$CURRENT_REMOTE_CLEAN" = "$EXPECTED_REMOTE_CLEAN" ]; then
            echo "→ Remote matches. Pulling latest changes..."
            git status --short
            git pull --quiet || {
                echo "→ Git pull failed – trying with --ff-only"
                git pull --ff-only || exit 1
            }
        else
            echo "→ Remote mismatch."
            echo "  Found:    $CURRENT_REMOTE_CLEAN"
            echo "  Expected: $EXPECTED_REMOTE_CLEAN"
            echo "→ Re-cloning repository..."
            cd / || exit 1
            rm -rf /app
        fi
    elif [ -d "/app" ]; then
        echo "→ /app exists but is not a git repo. Cleaning up..."
        cd / || exit 1
        rm -rf /app
    fi

    if [ ! -d "/app" ]; then
        echo "→ Cloning $(basename "${GIT_REPO_URL}") (depth=${GIT_CLONE_DEPTH:-1}) ..."
        git clone --depth="${GIT_CLONE_DEPTH:-1}" "$CLONE_URL" /app
        echo "→ Repository cloned into /app"
    fi

    cd /app || exit 1

    if [ -n "${APT_PACKAGES:-}" ]; then
        echo "→ Installing extra Ubuntu packages: ${APT_PACKAGES}"
        apt-get update -qq
        # shellcheck disable=SC2086
        apt-get install -y --no-install-recommends ${APT_PACKAGES}
        rm -rf /var/lib/apt/lists/* /var/cache/apt/*
        echo "→ Extra packages installed"
    else
        echo "→ No extra APT_PACKAGES requested"
    fi

    if [ -f "pnpm-lock.yaml" ]; then
        echo "→ Detected pnpm-lock.yaml → running pnpm install"
        pnpm install --frozen-lockfile --prefer-offline || {
            echo "→ pnpm install failed – retrying with verbose output:"
            pnpm install --frozen-lockfile
            exit 1
        }
    elif [ -f "yarn.lock" ]; then
        echo "→ Detected yarn.lock → running yarn install"
        yarn install --frozen-lockfile --prefer-offline || {
            echo "→ yarn install failed – retrying:"
            yarn install --frozen-lockfile
            exit 1
        }
    elif [ -f "package-lock.json" ]; then
        echo "→ Detected package-lock.json → running npm ci"
        npm ci --prefer-offline --no-audit --no-fund || {
            echo "→ npm ci failed – retrying:"
            npm ci --prefer-offline --no-audit --no-fund
            exit 1
        }
    else
        echo "→ No lockfile detected → running npm install"
        npm install --prefer-offline --no-audit --no-fund || {
            echo "→ npm install failed – retrying:"
            npm install --prefer-offline --no-audit --no-fund
            exit 1
        }
    fi

    echo "→ Playwright browsers are preinstalled (Chromium only)"
    echo "→ Using PLAYWRIGHT_BROWSERS_PATH=/ms-playwright"

    echo ""
    echo "→ Starting application: ${START_CMD}"
    echo "───────────────────────────────────────────────"

    # ─── This is the important fix ───
    exec /bin/sh -c "${START_CMD}"
    # ─────────────────────────────────
}

main "$@"