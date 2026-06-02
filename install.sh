#!/bin/sh

set -eu

VERSION="${HENGSHI_CLI_VERSION:-}"
BASE_URL="${HENGSHI_CLI_BASE_URL:-https://download.hengshi.com/cli}"
INSTALL_DIR="${INSTALL_DIR:-}"
DRY_RUN=0
WITH_SKILLS=0
SKILLS_AGENTS=""

usage() {
    cat <<EOF
Install HENGSHI CLI from the public static distribution.

Usage:
  curl -fsSL ${BASE_URL}/install.sh | sh
  curl -fsSL ${BASE_URL}/install.sh | sh -s -- --with-skills
  curl -fsSL ${BASE_URL}/install.sh | sh -s -- --with-skills --agent openclaw --agent claude-code

Options:
  --version <version>      Install a specific version (default: latest published version)
  --install-dir <path>     Install directory override
  --with-skills            Also install bundled official skills into detected agent skill dirs
  --agent <name>           Install bundled official skills into a specific supported agent dir
                           (repeatable; implies --with-skills)
  --dry-run                Print resolved URLs and install target without downloading
  -h, --help               Show this help

Environment:
  HENGSHI_CLI_VERSION      Version override
  HENGSHI_CLI_BASE_URL     Base download URL override
  INSTALL_DIR              Install directory override
EOF
}

fail() {
    echo "Error: $*" >&2
    exit 1
}

fetch_stdout() {
    url="$1"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- "$url"
    else
        fail "curl or wget is required"
    fi
}

resolve_latest_version() {
    latest_json="$(fetch_stdout "${BASE_URL%/}/latest.json")" ||
        fail "failed to fetch ${BASE_URL%/}/latest.json"
    latest_version="$(printf '%s\n' "$latest_json" | sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
    [ -n "$latest_version" ] || fail "failed to parse version from ${BASE_URL%/}/latest.json"
    printf '%s\n' "$latest_version"
}

resolve_home_relative_path() {
    case "$1" in
        "~/"*)
            relative_path="${1#\~/}"
            printf '%s/%s\n' "$HOME" "$relative_path"
            ;;
        *)
            printf '%s\n' "$1"
            ;;
    esac
}

list_supported_agents() {
    manifest="$1"
    awk -F '\t' '
        NR > 1 && $1 != "" {
            printf "%s%s", (count++ ? ", " : ""), $1
        }
        END { printf "\n" }
    ' "$manifest"
}

lookup_agent_path() {
    manifest="$1"
    agent_name="$2"
    awk -F '\t' -v requested="$agent_name" 'NR > 1 && $1 == requested { print $3; exit }' "$manifest"
}

append_unique_line() {
    value="$1"
    file="$2"
    touch "$file"
    if ! grep -Fx "$value" "$file" >/dev/null 2>&1; then
        printf '%s\n' "$value" >> "$file"
    fi
}

collect_skill_targets() {
    manifest="$1"
    target_file="$2"
    : > "$target_file"

    if [ -n "$SKILLS_AGENTS" ]; then
        for agent_name in $SKILLS_AGENTS; do
            raw_path="$(lookup_agent_path "$manifest" "$agent_name")"
            [ -n "$raw_path" ] || fail "unsupported --agent '$agent_name'. Supported agents: $(list_supported_agents "$manifest")"
            append_unique_line "$(resolve_home_relative_path "$raw_path")" "$target_file"
        done
    else
        while IFS="$(printf '\t')" read -r agent_name _display_name raw_path; do
            [ "$agent_name" = "agent" ] && continue
            [ -n "$agent_name" ] || continue
            resolved_path="$(resolve_home_relative_path "$raw_path")"
            detect_dir="$(dirname "$resolved_path")"
            if [ -d "$detect_dir" ]; then
                append_unique_line "$resolved_path" "$target_file"
            fi
        done < "$manifest"
    fi

    if [ ! -s "$target_file" ]; then
        fail "could not auto-detect any supported agent config directories. Re-run with --agent <name>. Supported agents: $(list_supported_agents "$manifest")"
    fi
}

install_bundled_skills() {
    skills_root="$1"
    manifest="$2"
    legacy_manifest="$3"
    target_file="$TMP_DIR/skill-targets.txt"

    [ -d "$skills_root" ] || fail "bundled skills directory missing from archive"
    [ -f "$manifest" ] || fail "supported agents manifest missing from archive"

    collect_skill_targets "$manifest" "$target_file"

    skill_count=0
    for skill_dir in "$skills_root"/*; do
        [ -d "$skill_dir" ] || continue
        skill_count=$((skill_count + 1))
    done
    [ "$skill_count" -gt 0 ] || fail "no bundled skills found in archive"

    while IFS= read -r target_dir; do
        [ -n "$target_dir" ] || continue
        mkdir -p "$target_dir"

        if [ -f "$legacy_manifest" ]; then
            while IFS= read -r legacy_skill; do
                [ -n "$legacy_skill" ] || continue
                rm -rf "$target_dir/$legacy_skill"
            done < "$legacy_manifest"
        fi

        for skill_dir in "$skills_root"/*; do
            [ -d "$skill_dir" ] || continue
            skill_name="$(basename "$skill_dir")"
            rm -rf "$target_dir/$skill_name"
            cp -R "$skill_dir" "$target_dir/"
        done

        echo "Installed official skills to ${target_dir}"
    done < "$target_file"
}

write_updater_state() {
    set -- internal updater write-state \
        --installer-kind shell \
        --install-dir "$INSTALL_DIR" \
        --managed-binary-path "$INSTALL_DIR/hbi"

    if [ "$WITH_SKILLS" -eq 1 ]; then
        set -- "$@" --with-skills
        if [ -n "$SKILLS_AGENTS" ]; then
            set -- "$@" --skills-target-mode explicit
            for agent_name in $SKILLS_AGENTS; do
                set -- "$@" --agent "$agent_name"
            done
        else
            set -- "$@" --skills-target-mode auto-detect
        fi

        if [ -f "$TMP_DIR/skill-targets.txt" ]; then
            while IFS= read -r target_dir; do
                [ -n "$target_dir" ] || continue
                set -- "$@" --resolved-skill-target "$target_dir"
            done < "$TMP_DIR/skill-targets.txt"
        fi
    fi

    "$INSTALL_DIR/hbi" "$@"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --version)
            [ $# -ge 2 ] || fail "--version requires a value"
            VERSION="$2"
            shift 2
            ;;
        --install-dir)
            [ $# -ge 2 ] || fail "--install-dir requires a value"
            INSTALL_DIR="$2"
            shift 2
            ;;
        --with-skills)
            WITH_SKILLS=1
            shift
            ;;
        --agent)
            [ $# -ge 2 ] || fail "--agent requires a value"
            SKILLS_AGENTS="${SKILLS_AGENTS}${SKILLS_AGENTS:+ }$2"
            WITH_SKILLS=1
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

case "$(uname -s)" in
    Darwin) platform="darwin" ;;
    Linux) platform="linux" ;;
    *) fail "unsupported OS: $(uname -s)" ;;
esac

case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) fail "unsupported architecture: $(uname -m)" ;;
esac

if [ -z "$INSTALL_DIR" ]; then
    for candidate in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin"; do
        if [ -d "$candidate" ] && [ -w "$candidate" ]; then
            INSTALL_DIR="$candidate"
            break
        fi
    done
fi

if [ -z "$INSTALL_DIR" ]; then
    INSTALL_DIR="$HOME/.local/bin"
fi

if [ -z "$VERSION" ]; then
    VERSION="$(resolve_latest_version)"
fi

LEGACY_BIN_PATH="${INSTALL_DIR}/everest"
ARCHIVE_NAME="hengshi-cli-${VERSION}-${platform}-${arch}.tar.gz"
ARCHIVE_URL="${BASE_URL}/${VERSION}/${ARCHIVE_NAME}"
CHECKSUM_URL="${BASE_URL}/${VERSION}/checksums.txt"

fetch() {
    url="$1"
    output="$2"
    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$output"
    elif command -v wget >/dev/null 2>&1; then
        wget -qO "$output" "$url"
    else
        fail "curl or wget is required"
    fi
}

sha256_file() {
    file="$1"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
    else
        fail "shasum or sha256sum is required"
    fi
}

if [ "$DRY_RUN" -eq 1 ]; then
    printf 'VERSION=%s\n' "$VERSION"
    printf 'BASE_URL=%s\n' "$BASE_URL"
    printf 'ARCHIVE_URL=%s\n' "$ARCHIVE_URL"
    printf 'CHECKSUM_URL=%s\n' "$CHECKSUM_URL"
    printf 'INSTALL_DIR=%s\n' "$INSTALL_DIR"
    printf 'LEGACY_BINARY_PATH=%s\n' "$LEGACY_BIN_PATH"
    if [ -e "$LEGACY_BIN_PATH" ] || [ -L "$LEGACY_BIN_PATH" ]; then
        printf 'REMOVE_LEGACY_BINARY=true\n'
    else
        printf 'REMOVE_LEGACY_BINARY=false\n'
    fi
    if [ "$WITH_SKILLS" -eq 1 ]; then
        printf 'WITH_SKILLS=true\n'
        if [ -n "$SKILLS_AGENTS" ]; then
            printf 'SKILLS_AGENTS=%s\n' "$SKILLS_AGENTS"
        else
            printf 'SKILLS_AGENTS=auto-detect\n'
        fi
        printf 'SKILLS_MODE=bundled-archive\n'
    else
        printf 'WITH_SKILLS=false\n'
    fi
    exit 0
fi

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/hengshi-cli-install.XXXXXX")"

cleanup() {
    rm -rf "$TMP_DIR"
}

trap cleanup EXIT HUP INT TERM

mkdir -p "$INSTALL_DIR"

ARCHIVE_PATH="$TMP_DIR/$ARCHIVE_NAME"
CHECKSUM_PATH="$TMP_DIR/checksums.txt"

echo "Downloading ${ARCHIVE_NAME}..."
fetch "$ARCHIVE_URL" "$ARCHIVE_PATH"

echo "Downloading checksums..."
fetch "$CHECKSUM_URL" "$CHECKSUM_PATH"

EXPECTED_HASH="$(grep "[[:space:]]${ARCHIVE_NAME}\$" "$CHECKSUM_PATH" | awk '{print $1}' | head -n 1)"
[ -n "$EXPECTED_HASH" ] || fail "missing checksum entry for ${ARCHIVE_NAME}"

ACTUAL_HASH="$(sha256_file "$ARCHIVE_PATH")"
[ "$EXPECTED_HASH" = "$ACTUAL_HASH" ] || fail "checksum mismatch for ${ARCHIVE_NAME}"

tar -xzf "$ARCHIVE_PATH" -C "$TMP_DIR"
BIN_PATH="$(find "$TMP_DIR" -type f -name hbi | head -n 1)"
[ -n "$BIN_PATH" ] || fail "could not find extracted hbi binary"
BUNDLED_SKILLS_DIR="$TMP_DIR/skills"
SUPPORTED_AGENTS_PATH="$TMP_DIR/supported-agents.tsv"
LEGACY_SKILLS_PATH="$TMP_DIR/legacy-skill-names.txt"

if command -v install >/dev/null 2>&1; then
    install -m 0755 "$BIN_PATH" "$INSTALL_DIR/hbi"
else
    cp "$BIN_PATH" "$INSTALL_DIR/hbi"
    chmod 0755 "$INSTALL_DIR/hbi"
fi

echo "Installed hbi to ${INSTALL_DIR}/hbi"
if [ -e "$LEGACY_BIN_PATH" ] || [ -L "$LEGACY_BIN_PATH" ]; then
    rm -f "$LEGACY_BIN_PATH"
    echo "Removed legacy everest binary from ${LEGACY_BIN_PATH}"
fi
case ":${PATH}:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
        echo "Note: ${INSTALL_DIR} is not currently in PATH."
        ;;
esac

if [ "$WITH_SKILLS" -eq 1 ]; then
    install_bundled_skills "$BUNDLED_SKILLS_DIR" "$SUPPORTED_AGENTS_PATH" "$LEGACY_SKILLS_PATH"
fi

write_updater_state
