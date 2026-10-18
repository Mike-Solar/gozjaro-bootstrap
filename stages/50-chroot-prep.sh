#!/usr/bin/env bash
# Ch. 7.2–7.4: hand $LFS back to root, mount kernel virtual FS, enter chroot,
# and re-invoke build.sh for stages 51/60/70 inside it.
# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"

start_log 50-chroot-prep
require_root

# Change ownership of the built tree back to root:root. Some entries (e.g.
# /tools, /lib64) only exist on certain hosts/stages — chown only what's there.
for d in usr lib var etc bin sbin tools sources lib64; do
    [ -e "$LFS/$d" ] || continue
    chown -R root:root "$LFS/$d"
done

# Prepare virtual kernel file systems.
mkdir -pv "$LFS"/{dev,proc,sys,run}

mount_if_needed() {
    mountpoint -q "$2" && return 0
    mount -v --bind "$1" "$2"
}

mount_if_needed /dev  "$LFS/dev"
mount -v --bind /dev/pts "$LFS/dev/pts" 2>/dev/null || \
    mount -vt devpts devpts -o gid=5,mode=0620 "$LFS/dev/pts"
mountpoint -q "$LFS/proc" || mount -vt proc  proc  "$LFS/proc"
mountpoint -q "$LFS/sys"  || mount -vt sysfs sysfs "$LFS/sys"
mountpoint -q "$LFS/run"  || mount -vt tmpfs tmpfs "$LFS/run"

if [ -h "$LFS/dev/shm" ]; then
    install -v -d -m 1777 "$LFS$(realpath /dev/shm)"
else
    mountpoint -q "$LFS/dev/shm" || mount -vt tmpfs -o nosuid,nodev tmpfs "$LFS/dev/shm"
fi

# Mirror the repo inside the chroot so build.sh keeps working.
mkdir -p "$LFS/gozjaro"
mountpoint -q "$LFS/gozjaro" || mount --bind "$GOZJARO_ROOT" "$LFS/gozjaro"

# Chroot marker used by lib/common.sh::require_chroot.
touch "$LFS/.gozjaro-chroot"

_chroot_env=(
    HOME=/root
    "TERM=$TERM"
    "PS1=(gozjaro chroot) \\u:\\w\\$ "
    PATH=/usr/bin:/usr/sbin
    GOZJARO_ROOT=/gozjaro
    LFS=
    "MAKEFLAGS=$MAKEFLAGS"
    "BUILD_MODE=${BUILD_MODE:-source}"
)

# Pass GOZPAK_REPOS into the chroot if set (needed for binary mode).
[ -z "${GOZPAK_REPOS:-}" ] || _chroot_env+=("GOZPAK_REPOS=$GOZPAK_REPOS")

# Forward per-stage --force into the chroot. GOZJARO_FORCE is a comma
# separated list of chroot stage names (bare numbers OK, or '*' to force
# every stage in the chain), e.g.:
#     sudo GOZJARO_FORCE=80-kernel,85-initramfs ./build.sh --force 50
# re-runs only 80-kernel and 85-initramfs inside the chroot; the other
# stages (51/60/70/75/77) keep their normal marker-skip behaviour.
# Without the variable, behaviour is identical to before.
[ -n "${GOZJARO_FORCE:-}" ] && _chroot_env+=("GOZJARO_FORCE=${GOZJARO_FORCE}")

# The chroot-side script is single-quoted on purpose: $(gforce ...) must be
# expanded INSIDE the chroot, not by the host shell. gforce() reads
# GOZJARO_FORCE from the environment (carried in _chroot_env above) and
# echoes "--force" when its argument (a stage name or bare number) is in
# the list, so each stage runs forced or marker-checked independently.
if [ "${BUILD_MODE:-source}" = "binary" ]; then
    log "entering chroot to run binary-mode stages (35, 36, 70, 80, 85)"
    chroot "$LFS" /usr/bin/env -i "${_chroot_env[@]}" \
        /bin/bash -lc '
            set -e
            cd /gozjaro
            gforce() {
                case "${GOZJARO_FORCE:-}" in "" ) return 0 ;; esac
                case "${GOZJARO_FORCE}" in *"*"*) echo "--force" ;; esac
                case ",${GOZJARO_FORCE}," in
                    *",${1},"*)     echo "--force" ;;   # full name: 80-kernel
                    *",${1%%-*},"*) echo "--force" ;;   # bare number: 80
                esac
            }
            ./build.sh --mode binary $(gforce 35-gozpak-bootstrap) 35-gozpak-bootstrap
            ./build.sh --mode binary $(gforce 36-binary-install) 36-binary-install
            ./build.sh --mode binary $(gforce 70-system-config) 70-system-config
            ./build.sh --mode binary $(gforce 80-kernel) 80-kernel
            ./build.sh --mode binary $(gforce 85-initramfs) 85-initramfs
        '
else
    log "entering chroot to run source-mode stages"
    chroot "$LFS" /usr/bin/env -i "${_chroot_env[@]}" \
        /bin/bash -lc '
            set -e
            cd /gozjaro
            gforce() {
                case "${GOZJARO_FORCE:-}" in "" ) return 0 ;; esac
                case "${GOZJARO_FORCE}" in *"*"*) echo "--force" ;; esac
                case ",${GOZJARO_FORCE}," in
                    *",${1},"*)     echo "--force" ;;   # full name: 80-kernel
                    *",${1%%-*},"*) echo "--force" ;;   # bare number: 80
                esac
            }
            ./build.sh $(gforce 51-chroot-tools) 51-chroot-tools
            ./build.sh $(gforce 60-final-system) 60-final-system
            ./build.sh $(gforce 70-system-config) 70-system-config
            ./build.sh $(gforce 75-live-tools) 75-live-tools
            ./build.sh $(gforce 77-grub) 77-grub
            ./build.sh $(gforce 80-kernel) 80-kernel
            ./build.sh $(gforce 85-initramfs) 85-initramfs
        '
fi
log "chroot stages returned successfully"
