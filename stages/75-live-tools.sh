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
    # curl 8.23.0 is built natively against OpenSSL 4.x: its vtls/openssl.c
    # uses the ASN1_STRING_get0_data()/_get_length()/_type() accessors
    # (since 1.1.0, works on 3.x and 4.x) instead of the raw struct-field
    # access that 8.14.1 still had (num->type/->data, psig->length/->data)
    # and that OpenSSL 4.0's opaqued struct asn1_string_st broke. Upstream
    # landed the port in the 8.19+ series; 8.23.0 is the current stable.
    # No source patches needed.
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
    # OpenSSL 4.0 removed the entire SSLv3 layer: no SSLv3_client_method()
    # and no OPENSSL_NO_SSL3_METHOD guard macro either. wget 1.25.0's
    # "secure-protocol sslv3" case is guarded by '#ifndef
    # OPENSSL_NO_SSL3_METHOD', which under 4.0 lets the dead call through
    # -> implicit declaration (a hard error under a C23 default toolchain).
    # Add a version gate: < 4.0 keeps the old behavior, >= 4.0 excludes the
    # call so 'meth' stays NULL and ssl_init's existing '!meth' handling
    # (line ~293) reports it cleanly. The default protocol (auto/pfs) uses
    # SSLv23_client_method() (= TLS_client_method() under 4.0), so only an
    # explicit --secure-protocol=ssl3 is affected, and that's dead anyway.
    # 1.25.0 is the newest Gnu wget (no 1.26 / no openssl-4 backport), so
    # patch in place. Target '#ifndef OPENSSL_NO_SSL3_METHOD' is unique in
    # the tree.
    sed -i 's/#ifndef OPENSSL_NO_SSL3_METHOD/#if !defined(OPENSSL_NO_SSL3_METHOD) \&\& OPENSSL_VERSION_NUMBER < 0x40000000L/' src/openssl.c

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
