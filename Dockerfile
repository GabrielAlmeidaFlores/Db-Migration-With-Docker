# Dockerfile for DB Migration Manager
# Allows running the script on any OS (Windows, macOS, Linux)

FROM debian:bullseye-slim

LABEL version="1.5.1"
LABEL description="Database Migration Manager - Docker Mode"

# Set UTF-8 locale for emoji support
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# Install required packages
RUN apt-get update && apt-get install -y \
    bash \
    dialog \
    curl \
    ca-certificates \
    gnupg \
    lsb-release \
    locales \
    dos2unix \
    && rm -rf /var/lib/apt/lists/* \
    && echo "C.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen

# Install Docker CLI (latest version)
RUN install -m 0755 -d /etc/apt/keyrings \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg \
    && chmod a+r /etc/apt/keyrings/docker.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Create working directory
WORKDIR /app

# Copy all scripts and dependencies
COPY db-manager.sh /app/
COPY lib/ /app/lib/
COPY operation/ /app/operation/
COPY dependencies/ /app/dependencies/

# Convert line endings from CRLF to LF (Windows to Linux)
RUN dos2unix /app/db-manager.sh /app/operation/*.sh /app/lib/*.sh

# Make scripts executable
RUN chmod +x /app/db-manager.sh /app/operation/*.sh /app/lib/*.sh

# Create volume mount points
RUN mkdir -p /dumps /config

# Set environment to use system dialog (since we install it)
ENV DIALOG=dialog

# Run the main script
ENTRYPOINT ["/app/db-manager.sh"]