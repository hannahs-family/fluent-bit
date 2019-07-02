ARG target=amd64
FROM ${target}/debian:stretch as builder

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update && \
  apt-get install -y --no-install-recommends \
  build-essential \
  cmake \
  make \
  wget \
  unzip \
  libssl1.0-dev \
  libasl-dev \
  libsasl2-dev \
  pkg-config \
  libsystemd-dev \
  zlib1g-dev \
  ca-certificates \
  flex \
  bison \
  && mkdir -p /fluent-bit/bin /fluent-bit/etc /fluent-bit/log /tmp/fluent-bit-master/

# Fluent Bit version
ARG FLB_VERSION=1.2.0
ARG FLB_MAJOR=1
ARG FLB_MINOR=2
ARG FLB_PATCH=0
ENV FLB_MAJOR=${FLB_MAJOR}
ENV FLB_MINOR=${FLB_MINOR}
ENV FLB_PATCH=${FLB_PATCH}
ENV FLB_VERSION=${FLB_VERSION}

ENV FLB_TARBALL http://github.com/fluent/fluent-bit/archive/v$FLB_VERSION.zip

RUN wget -O "/tmp/fluent-bit-${FLB_VERSION}.zip" ${FLB_TARBALL} \
  && cd /tmp && unzip "fluent-bit-$FLB_VERSION.zip" \
  && cd "fluent-bit-$FLB_VERSION"/build/ \
  && rm -rf /tmp/fluent-bit-$FLB_VERSION/build/*

WORKDIR /tmp/fluent-bit-$FLB_VERSION/build/
RUN cmake -DFLB_DEBUG=On \
  -DFLB_TRACE=Off \
  -DFLB_JEMALLOC=On \
  -DFLB_TLS=On \
  -DFLB_SHARED_LIB=Off \
  -DFLB_EXAMPLES=Off \
  -DFLB_HTTP_SERVER=On \
  -DFLB_IN_SYSTEMD=On ..

RUN make -j $(getconf _NPROCESSORS_ONLN)
RUN install bin/fluent-bit /fluent-bit/bin/

# Configuration files
COPY fluent-bit.conf \
  parsers.conf \
  parsers_java.conf \
  parsers_extra.conf \
  parsers_openstack.conf \
  parsers_cinder.conf \
  plugins.conf \
  /fluent-bit/etc/

FROM $target/debian:stretch
LABEL Description="Fluent Bit docker image" Vendor="Fluent Organization" Version="1.1"

ARG lib_target=x86_64

COPY --from=builder /usr/lib/${lib_target}/*sasl* /usr/lib/${lib_target}/
COPY --from=builder /usr/lib/${lib_target}/libz* /usr/lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/libz* /lib/${lib_target}/
COPY --from=builder /usr/lib/${lib_target}/libssl.so* /usr/lib/${lib_target}/
COPY --from=builder /usr/lib/${lib_target}/libcrypto.so* /usr/lib/${lib_target}/
# These below are all needed for systemd
COPY --from=builder /lib/${lib_target}/libsystemd* /lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/libselinux.so* /lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/liblzma.so* /lib/${lib_target}/
COPY --from=builder /usr/lib/${lib_target}/liblz4.so* /usr/lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/libgcrypt.so* /lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/libpcre.so* /lib/${lib_target}/
COPY --from=builder /lib/${lib_target}/libgpg-error.so* /lib/${lib_target}/

# Necessary for ssl to work from a Debian Stretch base
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/

COPY --from=builder /fluent-bit /fluent-bit

EXPOSE 2020

# Entry point
CMD ["/fluent-bit/bin/fluent-bit", "-c", "/fluent-bit/etc/fluent-bit.conf"]
