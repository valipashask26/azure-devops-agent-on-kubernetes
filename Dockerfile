# Use an Ubuntu-based image
ARG ARG_UBUNTU_BASE_IMAGE_TAG="20.04"
FROM ubuntu:${ARG_UBUNTU_BASE_IMAGE_TAG}

# Set working directory
WORKDIR /azp

# Set environment variables
ENV TARGETARCH=linux-x64
ENV VSTS_AGENT_VERSION=3.248.0

# Set APT frontend to non-interactive (automate installations)
ENV DEBIAN_FRONTEND=noninteractive
RUN echo "APT::Get::Assume-Yes \"true\";" > /etc/apt/apt.conf.d/90assumeyes

# Update and install required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    apt-transport-https \
    apt-utils \
    ca-certificates \
    curl \
    git \
    iputils-ping \
    jq \
    lsb-release \
    software-properties-common \
    && rm -rf /var/lib/apt/lists/*
RUN apt-get update && apt-get -y upgrade

# Install Docker Daemon
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
RUN echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \
    $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
RUN apt-get update \
    && apt-get install -y docker-ce docker-ce-cli containerd.io \
    && rm -rf /var/lib/apt/lists/*

# Install Azure CLI & Azure DevOps extension
RUN curl -LsS https://aka.ms/InstallAzureCLIDeb | bash \
    && rm -rf /var/lib/apt/lists/*
RUN az extension add --name azure-devops

# Install other required tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget \
    unzip

# Install yq
RUN wget https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && mv ./yq_linux_amd64 /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Install Helm
RUN curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash

# Install Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
    && mv ./kubectl /usr/bin/kubectl \
    && chmod +x /usr/bin/kubectl

# Install Powershell Core
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb" \
    && dpkg -i packages-microsoft-prod.deb
RUN apt-get update \
    && apt-get install -y powershell

# Start the Docker daemon inside the container (Docker-in-Docker)
RUN dockerd &

# Copy start script
COPY ./start.sh .
RUN chmod +x start.sh

# Create non-root user and add to Docker group
RUN useradd -m -s /bin/bash -u "1000" azdouser
RUN groupadd docker && usermod -aG docker azdouser
RUN apt-get update \
    && apt-get install -y sudo \
    && echo azdouser ALL=\(root\) NOPASSWD:ALL >> /etc/sudoers

# Change ownership of necessary directories
RUN sudo chown -R azdouser /home/azdouser
RUN sudo chown -R azdouser /azp
RUN sudo chown -R azdouser /var/run/docker.sock || true

# Set the user to azdouser
USER azdouser

# Set working directory again
WORKDIR /azp

# Define entrypoint to start the agent
ENTRYPOINT ["./start.sh"]
