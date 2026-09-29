#!/bin/sh
# Build a minimal PulseAudio for mr-do-soloist and collect its runtime files.
#
# Used by the Dockerfile builder stage (Debian trixie). Build dependencies:
#   build-essential cmake meson ninja-build pkgconf m4 libcap-dev libltdl-dev libspeexdsp-dev
#   (libcap: PulseAudio drops capabilities at start; without it, it logs a warning)
#
# Usage: build-pulseaudio.sh <pulseaudio source dir> <libsndfile source dir> <output dir>
#
#   1. libsndfile without codecs: PulseAudio links it (sample files), the pipe sink needs
#      no codecs. Debian's package pulls in FLAC, Vorbis, Opus, mpg123 and LAME.
#   2. PulseAudio without D-Bus, X11, systemd, udev, ALSA, ORC, soxr, ... Only the daemon,
#      the client library and pactl/pacat are used. Resampler: speexdsp (PulseAudio
#      default "speex-float-1").
#   3. <output dir> receives the runtime file set: pulseaudio, pactl, pacat, the 3 modules
#      the pipe sink setup loads, the libraries they link (except glibc) and libatomic
#      (linked by the Soloist binary). It is copied over a distroless base image.
#
# Environment (optional): STAGE (install staging dir, default /tmp/pa-stage),
# BUILD_DIR (default /tmp/pa-build), JOBS (default: nproc). Local builds without installed
# build dependencies: EXTRA_LIB_DIRS (colon-separated library dirs searched when resolving
# dependencies) and SYSROOT (prefix stripped from those library paths in <output dir>).
set -eu

PA_SRC="${1:?usage: build-pulseaudio.sh <pulseaudio src> <libsndfile src> <out>}"
SF_SRC="${2:?libsndfile source dir missing}"
OUT="${3:?output dir missing}"
STAGE="${STAGE:-/tmp/pa-stage}"
BUILD_DIR="${BUILD_DIR:-/tmp/pa-build}"
JOBS="${JOBS:-$(nproc)}"

# ---- 1. libsndfile (no external codec libraries) ------------------------------
cmake -S "${SF_SRC}" -B "${BUILD_DIR}/sndfile" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON \
    -DENABLE_EXTERNAL_LIBS=OFF -DENABLE_MPEG=OFF \
    -DBUILD_PROGRAMS=OFF -DBUILD_EXAMPLES=OFF -DBUILD_TESTING=OFF \
    -DENABLE_CPACK=OFF -DINSTALL_MANPAGES=OFF \
    -DCMAKE_INSTALL_PREFIX=/usr -DCMAKE_INSTALL_LIBDIR=lib
cmake --build "${BUILD_DIR}/sndfile" -j "${JOBS}"
DESTDIR="${STAGE}" cmake --install "${BUILD_DIR}/sndfile" --strip
# PulseAudio compiles and links against the staged copy (sndfile.pc has absolute paths)
sed -i -e "s#^prefix=.*#prefix=${STAGE}/usr#" \
       -e "s#^libdir=.*#libdir=${STAGE}/usr/lib#" \
       -e "s#^includedir=.*#includedir=${STAGE}/usr/include#" \
       "${STAGE}/usr/lib/pkgconfig/sndfile.pc"
export PKG_CONFIG_PATH="${STAGE}/usr/lib/pkgconfig${PKG_CONFIG_PATH:+:${PKG_CONFIG_PATH}}"
export LDFLAGS="${LDFLAGS:-} -Wl,-rpath-link,${STAGE}/usr/lib"

# ---- 2. PulseAudio -----------------------------------------------------------
# libdir=lib: /usr/lib is in the dynamic loader's default search path on every
# architecture (Soloist dlopen()s libpulse.so.0), no multiarch triplet needed.
meson setup "${BUILD_DIR}/pulseaudio" "${PA_SRC}" \
    --prefix=/usr --libdir=lib --sysconfdir=/etc --localstatedir=/var \
    --buildtype=release -Dstrip=true \
    -Ddaemon=true -Dclient=true -Ddatabase=simple \
    -Ddoxygen=false -Dgcov=false -Dman=false -Dtests=false \
    -Dbashcompletiondir=no -Dzshcompletiondir=no \
    -Dalsa=disabled -Dasyncns=disabled -Davahi=disabled \
    -Dbluez5=disabled -Dbluez5-gstreamer=disabled \
    -Dbluez5-native-headset=false -Dbluez5-ofono-headset=false \
    -Dconsolekit=disabled -Ddbus=disabled -Delogind=disabled -Dfftw=disabled \
    -Dglib=disabled -Dgsettings=disabled -Dgstreamer=disabled -Dgtk=disabled \
    -Dhal-compat=false -Dipv6=false -Djack=disabled -Dlirc=disabled \
    -Dopenssl=disabled -Dorc=disabled -Doss-output=disabled \
    -Dsamplerate=disabled -Dsoxr=disabled -Dspeex=enabled \
    -Dsystemd=disabled -Dtcpwrap=disabled -Dudev=disabled -Dvalgrind=disabled \
    -Dx11=disabled -Dwebrtc-aec=disabled -Dadrian-aec=false
ninja -C "${BUILD_DIR}/pulseaudio" -j "${JOBS}"
DESTDIR="${STAGE}" meson install -C "${BUILD_DIR}/pulseaudio" --no-rebuild --quiet

# ---- 3. collect the runtime file set ------------------------------------------
moddir="${STAGE}/usr/lib/pulseaudio/modules"
files="${STAGE}/usr/bin/pulseaudio ${STAGE}/usr/bin/pactl ${STAGE}/usr/bin/pacat
       ${moddir}/module-pipe-sink.so ${moddir}/module-native-protocol-unix.so
       ${moddir}/libprotocol-native.so"
mkdir -p "${OUT}"

# put <file> <target path inside the image>: copy, following symlinks (sonames)
put() { mkdir -p "${OUT}$(dirname "$2")"; cp -L "$1" "${OUT}$2"; }
for f in ${files}; do put "${f}" "${f#"${STAGE}"}"; done

# resolve shared libraries: staged ones keep their /usr/lib path, system ones their
# canonical path; glibc is part of the distroless base image
libpath="${STAGE}/usr/lib:${STAGE}/usr/lib/pulseaudio:${moddir}${EXTRA_LIB_DIRS:+:${EXTRA_LIB_DIRS}}"
deps="$(LD_LIBRARY_PATH="${libpath}" ldd ${files})"
if echo "${deps}" | grep "not found"; then echo "unresolved libraries" >&2; exit 1; fi
echo "${deps}" | awk '/=> \//{print $1, $3}' | sort -u | while read -r soname path; do
    case "${soname}" in
        libc.so.*|libm.so.*|libdl.so.*|libpthread.so.*|librt.so.*|libresolv.so.*|ld-linux*) continue ;;
    esac
    case "${path}" in
        "${STAGE}"/*) put "${path}" "${path#"${STAGE}"}" ;;
        *) d="$(readlink -f "$(dirname "${path}")")"; put "${path}" "${d#"${SYSROOT:-}"}/${soname}" ;;
    esac
done

# libatomic: linked by the Soloist binary, not part of distroless/cc
atomic="$( (ldconfig -p || /sbin/ldconfig -p) 2>/dev/null | awk '/libatomic\.so\.1 /{print $NF; exit}')"
[ -n "${atomic}" ] || atomic="$(find ${EXTRA_LIB_DIRS:+$(echo "${EXTRA_LIB_DIRS}" | tr ':' ' ')} /usr/lib -name libatomic.so.1 2>/dev/null | head -1)"
[ -n "${atomic}" ] || { echo "libatomic.so.1 not found" >&2; exit 1; }
d="$(readlink -f "$(dirname "${atomic}")")"; put "${atomic}" "${d#"${SYSROOT:-}"}/libatomic.so.1"

# merged /usr in the base image: /lib, /bin are symlinks and must not be replaced
test ! -e "${OUT}/lib" && test ! -e "${OUT}/bin"
find "${OUT}" -type f | sort
du -sh "${OUT}"
