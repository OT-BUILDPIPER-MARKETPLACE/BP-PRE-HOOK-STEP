FROM ubuntu:22.04

# Install dependencies (awscli, jq, shadow-utils equivalent)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    awscli \
    jq \
    passwd \
    shadow \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Create buildpiper user & group (non-root)
RUN groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m buildpiper && \
    mkdir -p /home/buildpiper && chown -R buildpiper:buildpiper /home/buildpiper

# Create required directories & assign permissions
RUN mkdir -p \
    /src/reports \
    /bp/data \
    /bp/execution_dir \
    /opt/buildpiper/shell-functions \
    /opt/buildpiper/data \
    /bp/workspace && \
    chown -R buildpiper:buildpiper /src /bp /opt

RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g npm@6.14.18

# Set environment variables
ENV SLEEP_DURATION=5s

# Copy files with correct ownership
COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

# Set permissions on script and workspace
RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /bp/workspace && \
    mkdir -p /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /home/buildpiper

# Switch to non-root user
USER buildpiper

# Set working directory to user's home
WORKDIR /home/buildpiper

# Entrypoint and default command
ENTRYPOINT ["./build.sh"]

