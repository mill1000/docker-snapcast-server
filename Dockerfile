# Base image for builds
FROM alpine:latest AS build-base
# Common tools
RUN apk add --update build-base autoconf automake libtool pkgconfig cmake 
# Common dependencies
RUN apk add --update soxr-dev avahi-dev alsa-lib-dev

# Snapcast build image
FROM build-base AS snapcast-build
RUN apk add --update npm boost-dev libvorbis-dev opus-dev flac-dev expat-dev openssl-dev
# Snapweb dependency
WORKDIR /snapweb
COPY snapweb .
RUN npm install && npm ci && npm run build
# Snapcast
WORKDIR /snapcast
COPY snapcast .
RUN mkdir build && cd build && cmake .. -DCMAKE_INSTALL_PREFIX=/usr -DBUILD_SERVER=ON -DSNAPWEB_DIR=/snapweb/dist -DBUILD_CLIENT=OFF
RUN cd build && cmake --build . && DESTDIR=/snapcast-install cmake --install .

# Shairport-sync build image
FROM build-base AS shairport-sync-build
RUN apk add --update popt-dev libconfig-dev openssl-dev
# ALAC dependency
WORKDIR /alac
COPY alac .
RUN autoreconf -fi && ./configure
RUN make && make install && make install DESTDIR=/alac-install
# Shairport-sync
WORKDIR /shairport-sync
COPY shairport-sync .
RUN autoreconf -fi && ./configure --sysconfdir=/etc --with-soxr --with-avahi --with-ssl=openssl --with-metadata --with-apple-alac -with-stdout
RUN make && make install DESTDIR=/shairport-sync-install

# Librespot build image
FROM build-base AS librespot-build
RUN apk add --update rust cargo rust-bindgen clang-libclang
WORKDIR /librespot
COPY librespot .
RUN cargo build --release --no-default-features --features="rustls-tls-native-roots with-avahi"

# Snapcast-upnp build
FROM alpine:latest AS snapcast-upnp-build
RUN apk add --update python3 pipx
WORKDIR /snapcast-upnp
COPY snapcast-upnp .
RUN PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin PIPX_MAN_DIR=/usr/local/share/man pipx install .

# Run image
FROM alpine:latest
ARG DATADIR=/var/lib/snapserver
COPY --from=snapcast-build /snapcast-install /
COPY --from=shairport-sync-build /shairport-sync-install /
COPY --from=shairport-sync-build /alac-install /
COPY --from=librespot-build /librespot/target/release/librespot /usr/local/bin/librespot
COPY --from=snapcast-upnp-build /opt/pipx /opt/pipx
COPY --from=snapcast-upnp-build /usr/local/bin/snapcast-upnp /usr/local/bin/snapcast-upnp
RUN apk add --update tini popt soxr libconfig libvorbis opus flac alsa-lib libgcc libstdc++ expat avahi-libs openssl doas python3
RUN adduser -D -H snapserver
RUN mkdir -p $DATADIR && chown snapserver:snapserver $DATADIR
RUN mkdir -p /streams && chown snapserver:snapserver /streams
# Allow snapserver user to nice process
RUN echo "permit nopass keepenv snapserver as root cmd /bin/nice" >> /etc/doas.d/snapserver-nice.conf
USER snapserver
ENV OPTIONS=
ENV NICE=-10
ENV DATADIR=$DATADIR
# HTTP RPC = 1780, TCP RPC = 1705, Stream = 1704
EXPOSE 1780
EXPOSE 1705 
EXPOSE 1704
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/sh", "-c", "doas /bin/nice -n $NICE /usr/bin/snapserver --server.datadir=$DATADIR $OPTIONS"]