#!/usr/bin/env bash
# Additional user-space tools for the live ISO and future installer:
# curl, wget, git, rsync, openssh, nano, parted, dosfstools.
# Runs inside the chroot, after stage 70 (system config) and before stage 80
# (kernel) so these tools land in the squashfs.
# shellcheck source=../lib/common.sh
. "$(dirname "$(readlink -f "$0")")/../lib/common.sh"
# shellcheck source=../lib/pkg.sh
. "$GOZJARO_ROOT/lib/pkg.sh"

start_log 75-live-tools
require_chroot
require_root

# ---- HTTP / download clients ------------------------------------------------

b_curl() {
    # OpenSSL 4.0 made X509_get_subject_name()/X509_get_issuer_name()
    # return 'const X509_NAME *'; curl 8.14.1's static helpers still
    # declare the local/param non-const -> hard type error at 1771
    # (x509_name_oneline, called from the subject/issuer lookups) and
    # 2405 (X509_NAME *name in ossl_verifyhost). Both locals are
    # read-only (fed to X509_NAME_print_ex / X509_NAME_get_index_by_NID,
    # which take const). curl is not in the LFS tree, so no official
    # patch — minimal source fix here.
    sed -i 's/x509_name_oneline(X509_NAME \*a/x509_name_oneline(const X509_NAME *a/' lib/vtls/openssl.c
    sed -i 's/X509_NAME \*name = X509_get_subject_name/const X509_NAME *name = X509_get_subject_name/' lib/vtls/openssl.c

    ./configure --prefix=/usr \
        --with-openssl \
        --without-libpsl \
        --disable-static \
        --disable-ldap \
        --with-ca-path=/etc/ssl/certs
    make
    make install
}

b_wget() {
    ./configure --prefix=/usr \
        --sysconfdir=/etc \
        --with-ssl=openssl \
        --disable-pcre2
    make
    make install
}

# ---- Version control --------------------------------------------------------

b_git() {
    # Build without Tcl/Tk (no gitk/git-gui) and without CPAN fallbacks.
    ./configure --prefix=/usr \
        --with-gitconfig=/etc/gitconfig \
        --without-tcltk
    make NO_TCLTK=1 NO_PERL_CPAN_FALLBACKS=1
    make NO_TCLTK=1 NO_PERL_CPAN_FALLBACKS=1 install
}

# ---- Sync / remote ----------------------------------------------------------

b_rsync() {
    # Keep it minimal — optional compression libs (lz4/zstd/xxhash) would
    # pull in more deps than a live ISO needs for v1.
    ./configure --prefix=/usr \
        --disable-xxhash \
        --disable-lz4 \
        --disable-zstd
    make
    make install
}

b_openssh() {
    install -v -m700 -d /var/lib/sshd
    chown root:sys /var/lib/sshd 2>/dev/null || true
    groupadd -g 50 sshd 2>/dev/null || true
    useradd -c 'sshd PrivSep' -d /var/lib/sshd -g sshd \
        -s /bin/false -u 50 sshd 2>/dev/null || true
    ./configure --prefix=/usr \
        --sysconfdir=/etc/ssh \
        --with-md5-passwords \
        --with-privsep-path=/var/lib/sshd \
        --with-default-path=/usr/bin \
        --with-superuser-path=/usr/sbin:/usr/bin \
        --with-pid-dir=/run \
        --without-pam
    make
    make install
    install -v -m755 contrib/ssh-copy-id /usr/bin 2>/dev/null || true

    # Install a minimal systemd unit if upstream didn't ship one.
    if [ ! -f /usr/lib/systemd/system/sshd.service ]; then
        cat > /usr/lib/systemd/system/sshd.service <<'EOF'
[Unit]
Description=OpenSSH Daemon
Wants=network-online.target
After=network-online.target

[Service]
ExecStartPre=/usr/bin/ssh-keygen -A
ExecStart=/usr/sbin/sshd -D
ExecReload=/bin/kill -HUP $MAINPID
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF
    fi
}

# ---- Editor -----------------------------------------------------------------

b_nano() {
    ./configure --prefix=/usr \
        --sysconfdir=/etc \
        --enable-utf8 \
        --docdir=/usr/share/doc/nano-8.3
    make
    make install
    install -v -m644 doc/sample.nanorc /etc/nanorc 2>/dev/null || true
}

# ---- Disk / filesystem tools ------------------------------------------------

b_parted() {
    ./configure --prefix=/usr \
        --disable-static \
        --disable-debug \
        --disable-device-mapper
    make
    make install
}

b_dosfstools() {
    ./configure --prefix=/usr \
        --enable-compat-symlinks \
        --mandir=/usr/share/man \
        --docdir=/usr/share/doc/dosfstools-4.2
    make
    make install
}

# ---- Invocations ------------------------------------------------------------

build_pkg 75.curl        "curl-"        b_curl
build_pkg 75.wget        "wget-"        b_wget
build_pkg 75.git         "git-"         b_git
build_pkg 75.rsync       "rsync-"       b_rsync
build_pkg 75.openssh     "openssh-"     b_openssh
build_pkg 75.nano        "nano-"        b_nano
build_pkg 75.parted      "parted-"      b_parted
build_pkg 75.dosfstools  "dosfstools-"  b_dosfstools

log "live tools installed"
