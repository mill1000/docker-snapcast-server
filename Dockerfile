# Base image for builds
FROM alpine:latest AS build-base
# Common tools
RUN apk add --update build-base autoconf automake libtool pkgconfig cmake 
# Common dependencies
RUN apk add --update soxr-dev avahi-dev alsa-lib-dev

# Snapcast build image
FROM build-base AS snapcast-sync-build
RUN apk add --update boost-dev libvorbis-dev opus-dev flac-dev expat-dev
WORKDIR /snapcast
COPY snapcast .
RUN mkdir build && cd build && cmake .. -DBUILD_SERVER=ON -DBUILD_CLIENT=OFF
RUN cd build && cmake --build . && cmake --install . --prefix /snapcast-install

# Shairport-sync build image
FROM build-base AS shairport-sync-build
RUN apk add --update popt-dev libconfig-dev openssl-dev
# ALAC Depdency
WORKDIR /alac
COPY alac .
RUN autoreconf -fi && ./configure
RUN make && make install && make install DESTDIR=/alac-install
# Shairport-sync
WORKDIR /shairport-sync
COPY shairport-sync .
RUN autoreconf -fi && ./configure --sysconfdir=/etc --with-soxr --with-avahi --with-ssl=openssl --with-metadata --with-apple-alac -with-stdout
RUN make && make install DESTDIR=/shairport-sync-install

# Run image
FROM alpine:latest
ARG DATADIR=/var/lib/snapserver
COPY --from=snapcast-sync-build /snapcast-install /
COPY --from=shairport-sync-build /shairport-sync-install /
COPY --from=shairport-sync-build /alac-install /
RUN apk add --update tini popt soxr libconfig libvorbis opus flac alsa-lib libgcc libstdc++ expat avahi-libs
RUN adduser -D -H snapserver
RUN mkdir -p $DATADIR && chown snapserver:snapserver $DATADIR
USER snapserver
ENV OPTIONS=
ENV DATADIR=$DATADIR
# HTTP RPC
# TCP RPC
# Stream
EXPOSE 1780
EXPOSE 1705 
EXPOSE 1704
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/sh", "-c", "/bin/snapserver --server.datadir=$DATADIR $OPTIONS"]