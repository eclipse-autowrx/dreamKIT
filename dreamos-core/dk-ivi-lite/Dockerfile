# ========================
# Builder stage
# ========================
FROM ubuntu:24.04 AS builder

WORKDIR /app

RUN apt-get update && apt-get install -y \
    git cmake build-essential libssl-dev libboost-all-dev curl \
    qt6-base-dev qt6-base-private-dev qt6-declarative-dev qt6-declarative-private-dev \
    libqt6concurrent6 libqt6quick6 qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtquick-window \
    qml6-module-qtqml-workerscript qml6-module-qtquick-templates \
    python3.12 python3.12-dev libpython3.12 pax-utils

COPY src /app/src

RUN mkdir /app/build && cd /app/build && \
    cmake ../src && \
    make -j$(nproc)

# ========================
# Runtime stage
# ========================
FROM ubuntu:24.04

ARG TARGETARCH

WORKDIR /app

RUN apt-get update && apt-get install -y \
    python3.12 libpython3.12 \
    libglx-mesa0 libgl1 libopengl0 \
    fontconfig libpng16-16 \
    libqt6core6 libqt6gui6 libqt6widgets6 \
    libqt6concurrent6 libqt6qml6 libqt6quick6 \
    qml6-module-qtquick qml6-module-qtquick-controls \
    qml6-module-qtquick-layouts qml6-module-qtquick-window \
    qml6-module-qtqml-workerscript qml6-module-qtquick-templates \
    libx11-xcb1 \
    libxcb1 \
    libxcb-util1 \
    libxrender1 \
    libxkbcommon-x11-0 \
    libxext6 \
    libxi6 \
    libxrandr2 \
    libxfixes3 \
    libxcursor1 \
    libxinerama1 \
    libxss1 \
    libglib2.0-0 \
    qml6-module-qtqml \
    qml6-module-qtqml-statemachine \
    iputils-ping sshpass \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/build/dk_ivi /app/exec/
COPY start.sh /app/
COPY ./src/library/target/${TARGETARCH} /app/exec/library

RUN chmod +x /app/start.sh

ENV LD_LIBRARY_PATH=/app/exec/library
ENV QML_IMPORT_PATH=/usr/lib/x86_64-linux-gnu/qt6/qml

CMD ["/app/exec/dk_ivi"]
