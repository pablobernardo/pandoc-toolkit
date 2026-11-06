# Distribution-pinned, not digest-locked: record image ID and installed versions per run.
FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    calibre xvfb xdotool scrot python3 python3-websocket \
    fonts-dejavu-core fonts-noto-color-emoji \
    && apt-get clean \
    && useradd --create-home --uid 1000 reader
COPY driver.py native.py evidence.py scenarios.py observe.js entrypoint.sh /opt/reader/
USER reader
ENV DISPLAY=:99 QTWEBENGINE_CHROMIUM_FLAGS="" \
    HOME=/tmp/reader-home XDG_RUNTIME_DIR=/tmp/reader-runtime
ENTRYPOINT ["bash", "/opt/reader/entrypoint.sh"]
