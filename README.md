# docker-snapcast-server
A Docker image for [Snapcast](https://github.com/badaix/snapcast) server with embedded shairport-sync and librespot based on Alpine linux.

## Minimal Compose Example
```yaml
services:
  snapcast:
    image: ghcr.io/mill1000/snapcast-server:latest
    container_name: snapcast-server
    restart: unless-stopped
    network_mode: host
    volumes:
      - /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket
      - /var/run/dbus:/var/run/dbus
```

## Compose Example With UPnP Support
Here's another compose example with support for UPnP via [docker-gmrender-resurrect-snapcast](https://github.com/mill1000/docker-gmrender-resurrect-snapcast).

```yaml
services:
  snapcast:
    image: ghcr.io/mill1000/snapcast-server:latest
    container_name: snapcast-server
    restart: unless-stopped
    network_mode: host
    volumes:
      - <SNAPSERVER_CONFIG>:/etc/snapserver.conf
      - /var/run/avahi-daemon/socket:/var/run/avahi-daemon/socket
      - /var/run/dbus:/var/run/dbus
      - snapcast-pipes:/streams
  
  gmrender-resurrect:
    image: ghcr.io/mill1000/gmrender-resurrect-snapcast:latest
    container_name: gmrender-resurrect
    restart: unless-stopped
    network_mode: host
    environment:
      FRIENDLY_NAME: "Snapcast"
      OPTIONS: "--port 59595 --mime-filter audio --gstout-audiopipe 'audioresample ! audioconvert ! audio/x-raw,rate=44100,format=S16LE,channels=2 ! filesink location=/snapcast/gmrender-resurrect'"
    volumes:
      - snapcast-pipes:/snapcast

volumes:
  snapcast-pipes:
```

Add a UPnP stream to `snapserver.conf`.
```
source = pipe:///streams/gmrender-resurrect?name=UPnP
```

Optionally, use the included stream plugin [snapcat-upnp](https://github.com/mill1000/snapcast-upnp) to add metadata support.
```
source = pipe:///streams/gmrender-resurrect?name=UPnP&controlscript=/usr/local/bin/snapcast-upnp&controlscriptparams=http://127.0.0.1:59595/description.xml
```
