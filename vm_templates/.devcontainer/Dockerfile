##### Don't forget to update links to Bitwarden and tfsec releases
# [Choice] Ubuntu version (use jammy on local arm64/Apple Silicon): jammy, focal
ARG VARIANT="jammy"
FROM ianepreston/base-devcontainer:${VARIANT}

# Install packer
RUN wget -O- https://apt.releases.hashicorp.com/gpg | \
	gpg --dearmor | \
	tee /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
	https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
	tee /etc/apt/sources.list.d/hashicorp.list && \
	apt update && \
	apt install -y packer

# Install qemu-utils
RUN apt install -y qemu-utils

# # Install node
RUN wget -O- https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | \
	gpg --dearmor | \
	tee /usr/share/keyrings/nodesource.gpg && \
	echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_21.x nodistro main" | \
	tee /etc/apt/sources.list.d/nodesource.list && \
	apt update && \
	apt install -y nodejs 

# Install xo-cli
RUN npm install --global xo-cli

# Install Bitwarden CLI
RUN wget -O bitwarden.zip https://github.com/bitwarden/clients/releases/download/cli-v2023.7.0/bw-linux-2023.7.0.zip && \
	unzip bitwarden.zip && \
	rm bitwarden.zip && \
	chmod +x bw && \
	mv bw /usr/bin/

# # Install diff-so-fancy (this should go in my base image)
RUN apt update && \
	apt install -y software-properties-common && \
	add-apt-repository ppa:aos1/diff-so-fancy && \
	apt update && \
	apt install -y diff-so-fancy