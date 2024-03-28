# Base image for builds
FROM alpine:latest AS build-base
# Common tools
RUN apk add --update build-base autoconf automake libtool pkgconfig cmake 
# Common dependencies
RUN apk add --update soxr-dev avahi-dev alsa-lib-dev

# Snapcast build image
FROM build-base AS snapcast-build
RUN apk add --update npm boost-dev libvorbis-dev opus-dev flac-dev expat-dev
# Snapweb dependency
WORKDIR /snapweb
COPY snapweb .
RUN npm ci && npm run build
# Snapcast
WORKDIR /snapcast
COPY snapcast .
RUN mkdir build && cd build && cmake .. -DBUILD_SERVER=ON -DSNAPWEB_DIR=/snapweb/dist -DBUILD_CLIENT=OFF
RUN cd build && cmake --build . && cmake --install . --prefix /snapcast-install

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
RUN apk add --update rust cargo
WORKDIR /librespot
COPY librespot .
# Patch taken from https://git.alpinelinux.org/aports/commit/?id=8adc8c00b84b9f87b5b22dcc7cac5644f42974c0
COPY librespot.patch .
RUN patch < librespot.patch && cargo build --release --no-default-features 

# Run image
FROM alpine:latest
ARG DATADIR=/var/lib/snapserver
COPY --from=snapcast-build /snapcast-install /
COPY --from=shairport-sync-build /shairport-sync-install /
COPY --from=shairport-sync-build /alac-install /
COPY --from=librespot-build /librespot/target/release/librespot /bin/librespot
RUN apk add --update tini popt soxr libconfig libvorbis opus flac alsa-lib libgcc libstdc++ expat avahi-libs
RUN adduser -D -H snapserver
RUN mkdir -p $DATADIR && chown snapserver:snapserver $DATADIR
RUN mkdir -p /streams && chown snapserver:snapserver /streams
USER snapserver
ENV OPTIONS=
ENV DATADIR=$DATADIR
# HTTP RPC = 1780, TCP RPC = 1705, Stream = 1704
EXPOSE 1780
EXPOSE 1705 
EXPOSE 1704
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/sh", "-c", "/bin/snapserver --server.datadir=$DATADIR $OPTIONS"]