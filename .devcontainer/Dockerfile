# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.148.1/containers/go/.devcontainer/base.Dockerfile

# [Choice] Go version: 1, 1.15, 1.14
ARG VARIANT="1"
FROM mcr.microsoft.com/vscode/devcontainers/go:0-${VARIANT}

# Add dependencies.
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends zsh curl

RUN mkdir -p /home/linuxbrew
RUN chown -R vscode:vscode  /home/linuxbrew
USER vscode

# Add linux brew.
RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH
RUN echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.zshrc

RUN brew install shfmt shellcheck

# Add zsh shell.
COPY .zshrc /home/vscode/.zshrc

RUN rm -rf ~/.cache

# Githooks settings
ENV GOPATH="/workspaces/githooks/githooks/.go"
ENV GOBIN="/workspaces/githooks/githooks/bin"
ENV GITHOOKS_REPO="/workspaces/githooks"
ENV GITHOOKS_BIN="/workspaces/githooks/githooks/bin"
