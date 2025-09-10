FROM ubuntu:22.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        awscli \
        jq \
        passwd \
        ca-certificates \
        curl \
    && rm -rf /var/lib/apt/lists/*


RUN groupadd -g 65522 buildpiper && \
    useradd -u 65522 -g buildpiper -d /home/buildpiper -m buildpiper && \
    chown -R buildpiper:buildpiper /home/buildpiper


RUN mkdir -p \
        /src/reports \
        /bp/data \
        /bp/execution_dir \
        /opt/buildpiper/shell-functions \
        /opt/buildpiper/data \
        /bp/workspace && \
    chown -R buildpiper:buildpiper /src /bp /opt


RUN curl -fsSL https://deb.nodesource.com/setup_14.x | bash - && \
    apt-get install -y --no-install-recommends \
        nodejs \
        git \
        openssh-client && \
    npm install -g npm@6.14.18


ENV SLEEP_DURATION=5s


COPY --chown=buildpiper:buildpiper build.sh /home/buildpiper/build.sh
COPY --chown=buildpiper:buildpiper BP-BASE-SHELL-STEPS /opt/buildpiper/shell-functions/

RUN chmod +x /home/buildpiper/build.sh && \
    chown -R buildpiper:buildpiper /bp/workspace && \
    mkdir -p /home/buildpiper/reports && \
    chown -R buildpiper:buildpiper /home/buildpiper


USER buildpiper


WORKDIR /home/buildpiper


ENTRYPOINT ["/home/buildpiper/build.sh"]
