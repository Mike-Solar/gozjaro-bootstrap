#!/usr/bin/env bash
# Download all source tarballs + patches into $LFS/sources and verify checksums.
#
# Downloads run serially with wget writing a live progress bar straight to the
# terminal (no tee, no GNU parallel — both interfere with real-time output).
# A concise summary is still appended to $LFS/var/gozjaro/log/.
#
# Package sources are read from YAML manifests in config/packages/, with
# backward-compatible fallback to the legacy packages.txt format.
#
# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

require_root
ensure_dirs

command -v wget >/dev/null || die "wget not installed"

mkdir -p "$SOURCES_DIR"
chmod a+wt "$SOURCES_DIR"
cd "$SOURCES_DIR"

# ---------------------------------------------------------------------------
# Manifest library
# ---------------------------------------------------------------------------
# shellcheck source=./lib/manifest.sh
. "${GOZJARO_ROOT}/lib/manifest.sh"

summary_log="${LOG_DIR}/$(date +%Y%m%d-%H%M%S)-20-fetch-sources.log"
touch "$summary_log"
logline() { printf '%s\n' "$*" | tee -a "$summary_log"; }

# ---------------------------------------------------------------------------
# Source URL list: YAML manifests or legacy packages.txt
# ---------------------------------------------------------------------------

get_source_urls() {
    # Returns a list of source URLs to download.
    # Priority: YAML manifests > legacy packages.txt.
    local urls=()
    local has_yaml=0

    # Try YAML manifests first
    if [ -d "$MANIFEST_DIR" ]; then
        for mfile in "${MANIFEST_DIR}"/*.yaml "${MANIFEST_DIR}"/*.yml; do
            [ -f "$mfile" ] || continue
            # Extract URLs from package definitions
            local pkg_names
            pkg_names=$(_manifest_extract_names_bash "$mfile")
            if [ -n "$pkg_names" ]; then
                has_yaml=1
                for name in $pkg_names; do
                    local url
                    url=$(manifest_get_download_url "$name" 2>/dev/null)
                    if [ -n "$url" ]; then
                        urls+=("$url")
                    fi
                done
            fi
        done
    fi

    if [ "$has_yaml" = "1" ]; then
        printf '%s\n' "${urls[@]}"
    elif [ -f "$LEGACY_PACKAGES_TXT" ]; then
        # Fallback to legacy format
        grep -vE '^\s*$' "$LEGACY_PACKAGES_TXT"
    elif [ -f "$LEGACY_BASE_PACKAGES_TXT" ]; then
        grep -vE '^\s*$' "$LEGACY_BASE_PACKAGES_TXT"
    else
        logline "WARNING: No package sources found (manifests or legacy)"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Patch download helper
# ---------------------------------------------------------------------------

download_patches_for_package() {
    local pkg_name="$1"
    local categories="${2:-base system kernel development live}"

    local patch_urls
    patch_urls=$(manifest_list_patches "$pkg_name" $categories 2>/dev/null)

    if [ -z "$patch_urls" ]; then
        return 0
    fi

    while IFS= read -r patch_url; do
        [ -z "$patch_url" ] && continue
        local patch_fn="${patch_url##*/}"
        local dest_path="${PATCHES_DIR:-.}/${patch_fn}"

        logline "  patch: $patch_fn"
        if [ ! -f "$dest_path" ]; then
            wget --timeout=30 --tries=1 --progress=bar:force:noscroll \
                 -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" -O "$dest_path" "$patch_url" 2>/dev/null || \
                logline "  WARN: Failed to download patch $patch_fn"
        fi
    done <<< "$patch_urls"
}

# ---------------------------------------------------------------------------
# Mirror + fallback download helper
# ---------------------------------------------------------------------------
# When GOZJARO_SOURCE_MIRROR=ustc, candidate URLs are [mirror, upstream];
# otherwise just [upstream]. This makes a wrong mirror-map entry a cache miss
# (never a build failure). LFS patches are never mirrored.
#
# Usage: download_url <dest-filename> <url> [upstream-or-not]
#   $3 = "mirror" -> compute mirror candidate and try it FIRST, then fall back
#                    to the given URL (upstream).
#   $3 = "direct" -> try the URL as-is.
# Returns 0 on success, 1 if every candidate failed.
download_url() {
    local fn="$1" url="$2" mode="${3:-direct}"
    local candidates=()
    if [ "$mode" = "mirror" ]; then
        candidates+=("$(manifest_mirror_url "$url")")
        [ "${candidates[0]}" != "$url" ] || candidates=()
    fi
    candidates+=("$url")

    local c
    for c in "${candidates[@]}"; do
        [ -z "$c" ] && continue
        if wget --timeout=30 --tries=2 --progress=bar:force:noscroll \
                -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                -O "$fn" "$c" 2>/dev/null; then
            # Guard: a 200 with an empty body (seen when a mirror's CDN blocks
            # the egress IP) still satisfies wget — reject it so we fall back.
            if [ -s "$fn" ]; then
                return 0
            fi
            logline "    empty response from ${c##*/}; falling back"
            rm -f -- "$fn" 2>/dev/null || true
        fi
        logline "    retry-next candidate failed: ${c##*/}"
    done
    return 1
}

# ---------------------------------------------------------------------------
# Main download loop
# ---------------------------------------------------------------------------

MIRROR_ACTIVE=0
case "${GOZJARO_SOURCE_MIRROR:-auto}" in
    ustc) MIRROR_ACTIVE=1 ;;
esac
[ "$MIRROR_ACTIVE" = "1" ] && logline "source mirror: USTC ($GOZJARO_MIRROR_MAP), with upstream fallback"
[ "$MIRROR_ACTIVE" = "1" ] && [ ! -r "${GOZJARO_MIRROR_MAP:-/dev/null}" ] && {
    logline "WARNING: mirror map not readable: ${GOZJARO_MIRROR_MAP}; using upstream directly"
}

source_urls=$(get_source_urls)
if [ -z "$source_urls" ]; then
    die "No source URLs found. Check config/packages/ or config/packages.txt"
fi

# ---------------------------------------------------------------------------
# LFS patch download pass
# ---------------------------------------------------------------------------
# Collect every patch URL referenced by the package manifests (package-level
# `patches:` blocks) plus the shared entries in patches.yaml, then fetch each
# into $SOURCES_DIR. These are applied verbatim by the build stages
# (30-cross-toolchain / 60-final-system). LFS patches are NOT mirrored — they
# stay on linuxfromscratch.org. Failures here are hard: the glibc FHS patch in
# particular is applied without `|| true`, so a missing patch aborts the build.
download_all_patches() {
    local all_urls
    all_urls=$({
        # Package-level patch URLs from every category manifest.
        grep -rhoE 'url:[[:space:]]*https?://[^[:space:]]+\.patch' \
            "${MANIFEST_DIR}"/*.yaml "${MANIFEST_DIR}"/*.yml 2>/dev/null \
            | sed -E 's/^url:[[:space:]]*//'
        # Shared/global patch URLs from patches.yaml (top-level `patches:` key).
        if [ -f "${MANIFEST_DIR}/patches.yaml" ]; then
            grep -hoE 'url:[[:space:]]*https?://[^[:space:]]+\.patch' \
                "${MANIFEST_DIR}/patches.yaml" 2>/dev/null \
                | sed -E 's/^url:[[:space:]]*//'
        fi
    } | sort -u)

    local count purl pfn pdst
    count=$(printf '%s\n' "$all_urls" | grep -cve '^\s*$' || true)
    logline "Downloading $count LFS patch files (upstream, not mirrored)"
    local pfail=0
    while IFS= read -r purl; do
        [ -z "$purl" ] && continue
        pfn="${purl##*/}"
        pdst="${SOURCES_DIR}/${pfn}"
        if [ -f "$pdst" ]; then
            logline "  patch: $pfn (cached)"
            continue
        fi
        if wget --timeout=30 --tries=2 --progress=bar:force:noscroll \
                -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
                -O "$pdst" "$purl" 2>/dev/null; then
            logline "  patch: $pfn ok"
        else
            logline "  patch: $pfn FAILED"
            pfail=1
        fi
    done <<< "$all_urls"
    [ "$pfail" = "0" ] || die "one or more LFS patches failed to download; check network"
}

download_all_patches

remove_invalid_cached_sources() {
    for mfile in "${MANIFEST_DIR}"/*.yaml "${MANIFEST_DIR}"/*.yml; do
        [ -f "$mfile" ] || continue

        local pkg_names
        pkg_names=$(_manifest_extract_names_bash "$mfile")
        for name in $pkg_names; do
            local checksum_value source_filename cached_file
            checksum_value=$(manifest_get_field "$name" "checksum_value" 2>/dev/null)
            [ -n "$checksum_value" ] || continue

            source_filename=$(manifest_get_filename "$name" 2>/dev/null || true)
            [ -n "$source_filename" ] || continue
            cached_file="${SOURCES_DIR}/$source_filename"
            [ -f "$cached_file" ] || continue

            if ! manifest_verify_checksum "$cached_file" "$name" 2>/dev/null; then
                warn "discarding cached source with invalid checksum: $source_filename"
                rm -f -- "$cached_file" || die "cannot remove invalid source: $cached_file"
            fi
        done
    done
}

remove_invalid_cached_sources

# Count total URLs
total=$(echo "$source_urls" | grep -cve '^\s*$')
idx=0
fail_list="$SOURCES_DIR/.fetch-failed"
: > "$fail_list"

logline "Downloading $total source files from YAML manifests (legacy fallback active)"

echo "$source_urls" | grep -vE '^\s*$' | while IFS= read -r url; do
    [ -z "$url" ] && continue
    idx=$((idx + 1))
    fn="${url##*/}"

    # Patches stay on upstream (LFS does not mirror them). Tarballs use the
    # mirror when GOZJARO_SOURCE_MIRROR=ustc, falling back to upstream.
    if [[ "$url" == *.patch ]]; then
        mode="direct"
    else
        [ "$MIRROR_ACTIVE" = "1" ] && mode="mirror" || mode="direct"
    fi

    logline "[$idx/$total] fetching $fn"
    if [ -f "$fn" ]; then
        logline "[$idx/$total] $fn already exists, skipping download"
        ok=1
    else
        ok=0
        for try in 1 2 3; do
            if download_url "$fn" "$url" "$mode"; then
                ok=1
                logline "[$idx/$total] ok $fn"
                break
            fi
            logline "[$idx/$total] retry $try $fn"
            sleep 2
        done
    fi
    if [ "$ok" = "0" ]; then
        logline "[$idx/$total] FAILED $fn"
        echo "$url" >> "$fail_list"
    fi
done

# Check for failures (fail_list is written inside subshell, so check files)
failed_files=""
if [ -s "$fail_list" ]; then
    failed_files=$(cat "$fail_list")
fi

if [ -n "$failed_files" ]; then
    warn "some downloads failed:"
    echo "$failed_files" >&2
    die "retry after fixing network/URLs"
fi

# ---------------------------------------------------------------------------
# Checksum verification
# ---------------------------------------------------------------------------

verify_downloaded_checksums() {
    local verified=0
    local skipped=0
    local errors=0

    for mfile in "${MANIFEST_DIR}"/*.yaml "${MANIFEST_DIR}"/*.yml; do
        [ -f "$mfile" ] || continue

        local pkg_names
        pkg_names=$(_manifest_extract_names_bash "$mfile")
        for name in $pkg_names; do
            local checksum_value
            checksum_value=$(manifest_get_field "$name" "checksum_value" 2>/dev/null)

            if [ -z "$checksum_value" ]; then
                skipped=$((skipped + 1))
                continue
            fi

            # Find matching file
            local matched_file=""
            local source_filename
            source_filename=$(manifest_get_filename "$name" 2>/dev/null || true)
            if [ -n "$source_filename" ] && [ -f "${SOURCES_DIR}/$source_filename" ]; then
                matched_file="${SOURCES_DIR}/$source_filename"
            fi

            for f in "${SOURCES_DIR}"/${name}-*; do
                [ -z "$matched_file" ] || break
                [ -f "$f" ] && matched_file="$f" && break
            done

            if [ -z "$matched_file" ]; then
                # Try partial match
                for f in "${SOURCES_DIR}"/*; do
                    if [ -f "$f" ] && echo "$f" | grep -qi "$name"; then
                        matched_file="$f"
                        break
                    fi
                done
            fi

            if [ -n "$matched_file" ]; then
                if manifest_verify_checksum "$matched_file" "$name" 2>/dev/null; then
                    verified=$((verified + 1))
                else
                    errors=$((errors + 1))
                fi
            fi
        done
    done

    logline "Checksum verification: $verified verified, $skipped skipped (no checksum), $errors errors"
    return $errors
}

# Run manifest-based checksum verification
verify_downloaded_checksums || die "one or more source checksum verifications failed"

# Fallback: also verify against upstream LFS md5sums if available
logline "checking upstream md5sums from $LFS_MD5_URL"
if wget --timeout=30 --tries=3 --progress=bar:force:noscroll \
        -U "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
        -O md5sums.upstream "$LFS_MD5_URL" 2>/dev/null; then
    grep -E "  ($(ls | tr '\n' '|' | sed 's/|$//'))\$" md5sums.upstream > md5sums.local 2>/dev/null || true
    if [ -s md5sums.local ]; then
        logline "verifying $(wc -l < md5sums.local) tarballs against upstream md5sums"
        if ! md5sum -c md5sums.local 2>/dev/null; then
            warn "some md5 checks failed; manifest checksums take priority"
        fi
    else
        logline "no matching entries in upstream md5sums; skipping verification"
    fi
    rm -f md5sums.upstream md5sums.local
else
    logline "could not fetch upstream md5sums; relying on manifest checksums only"
fi

log "sources ready in $SOURCES_DIR (summary: $summary_log)"