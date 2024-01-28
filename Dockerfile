# Build image
FROM alpine:latest AS build
RUN apk add --update build-base cmake boost-dev alsa-lib-dev libvorbis-dev opus-dev flac-dev soxr-dev avahi-dev expat-dev
WORKDIR /snapcast
COPY snapcast .
RUN mkdir build && cd build && cmake .. -DBUILD_SERVER=ON -DBUILD_CLIENT=OFF
RUN cd build && cmake --build . && cmake --install . --prefix /snapcast-install

Run image
FROM alpine:latest
COPY --from=build /snapcast-install /
RUN apk add --update tini avahi
ENV OPTIONS=
# HTTP RPC
EXPOSE 1780
# TCP RPC
EXPOSE 1705 
# Stream
EXPOSE 1704
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/bin/sh", "-c", "/bin/snapserver $OPTIONS"]