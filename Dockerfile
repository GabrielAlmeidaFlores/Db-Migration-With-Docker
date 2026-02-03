# Dockerfile for DB Migration Manager
# Allows running the script on any OS (Windows, macOS, Linux)

FROM debian:bullseye-slim

# Set UTF-8 locale for emoji support
ENV LANG=C.UTF-8 \
    LC_ALL=C.UTF-8 \
    TERM=xterm-256color

# Install required packages
RUN apt-get update && apt-get install -y \
    bash \
    dialog \
    docker.io \
    curl \
    locales \
    && rm -rf /var/lib/apt/lists/* \
    && echo "C.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen

# Create working directory
WORKDIR /app

# Copy all scripts and dependencies
COPY db-manager.sh /app/
COPY operations/ /app/operations/
COPY dependencies/ /app/dependencies/

# Make scripts executable
RUN chmod +x /app/db-manager.sh /app/operations/*.sh

# Create volume mount points
RUN mkdir -p /dumps /config

# Set environment to use system dialog (since we install it)
ENV DIALOG=dialog

# Run the main script
ENTRYPOINT ["/app/db-manager.sh"]
