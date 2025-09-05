# Stage 1: Builder stage with build dependencies
FROM python:3.10-slim-bookworm AS builder

ARG TARGETPLATFORM
ARG BUILDPLATFORM
ARG KUKSA_TAG=0.4.3  # Default tag, override at build time

RUN echo "-- Running on $BUILDPLATFORM, building for $TARGETPLATFORM"

WORKDIR /build

# Install build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    binutils \
    git \
    gcc \
    build-essential \
    python3-dev \
    && rm -rf /var/lib/apt/lists/*

# Clone the kuksa-can-provider repo
# RUN git clone --branch ${KUKSA_TAG} --depth 1 https://github.com/eclipse-kuksa/kuksa-can-provider.git
RUN git clone https://github.com/eclipse-kuksa/kuksa-can-provider.git

WORKDIR /build/kuksa-can-provider

# Upgrade pip and install build tools
RUN pip install --upgrade --no-cache-dir pip build pyinstaller

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy additional files needed for runtime
COPY /can-provider /build/kuksa-can-provider
COPY /prepare-dbc-file/ModelCAN.dbc /build/kuksa-can-provider
COPY /prepare-dbc-file/mapping/ /build/kuksa-can-provider/mapping/

# Build the executable with pyinstaller
# RUN pyinstaller --collect-data kuksa_client --hidden-import can.interfaces.socketcan --clean -F -s dbcfeeder.py
RUN pyinstaller --collect-data kuksa_client \
    --hidden-import can.interfaces.socketcan \
    --hidden-import kuksa_client.kuksa_logger \
    --clean -F -s dbcfeeder.py

# Fix scripts line endings and permissions
RUN sed -i -e 's/\r$//' *.sh && chmod +x *.sh

# Stage 2: Minimal runtime image
FROM python:3.10-slim-bookworm

WORKDIR /dist/kuksa-can-provider

# pyinstaller doesn't pick up transient libz dependency, so copying it manually
COPY --from=builder /usr/lib/*-linux-gnu/libz.so.1 /lib/

# Copy the built executable and scripts from builder stage
COPY --from=builder /build/kuksa-can-provider/config /dist/kuksa-can-provider/config
COPY --from=builder /build/kuksa-can-provider/dist/dbcfeeder /dist/kuksa-can-provider/dbcfeeder
COPY --from=builder /build/kuksa-can-provider/*.sh /dist/kuksa-can-provider/
COPY --from=builder /build/kuksa-can-provider/ModelCAN.dbc /dist/kuksa-can-provider/
COPY --from=builder /build/kuksa-can-provider/mapping /dist/kuksa-can-provider/mapping

# Make sure scripts and executable are executable
RUN chmod +x /dist/kuksa-can-provider/*.sh /dist/kuksa-can-provider/dbcfeeder

ENV PATH="/dist:/dist/kuksa-can-provider:$PATH"
ENV LOG_LEVEL="info"
ENV VEHICLEDATABROKER_DAPR_APP_ID=vehicledatabroker
ENV CAN_PORT=can1
ENV PYTHONUNBUFFERED=yes

CMD ["start.sh"]
