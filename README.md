# docker-snapcast-server
Dockerfile for a Snapcast server with embedded shairport-sync and librespot. Based on Alpine linux.

## Compose Example
```yaml
services:
  snapcast:
    image: snapcast-server:latest
    container_name: snapcast-server
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket
      - /var/run/dbus:/var/run/dbus
```