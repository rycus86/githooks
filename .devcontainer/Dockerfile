# See here for image contents: https://github.com/microsoft/vscode-dev-containers/tree/v0.148.1/containers/go/.devcontainer/base.Dockerfile

# [Choice] Go version: 1, 1.15, 1.14
ARG VARIANT="1"
FROM mcr.microsoft.com/vscode/devcontainers/go:0-${VARIANT}

# Change shell.
RUN chsh -s /bin/zsh vscode

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
RUN rm -rf ~/.cache

# Add zsh shell setup.
COPY .zshrc /home/vscode/.zshrc
ENV LANG=en_US.UTF-8
RUN /bin/zsh -c "source /home/vscode/.zshrc"


# Install Go tools
RUN go get github.com/mdempsky/gocode
RUN go get github.com/uudashr/gopkgs/v2/cmd/gopkgs
RUN go get github.com/ramya-rao-a/go-outline
RUN go get github.com/acroca/go-symbols
RUN go get golang.org/x/tools/cmd/guru
RUN go get golang.org/x/tools/cmd/gorename
RUN go get github.com/cweill/gotests
RUN go get github.com/fatih/gomodifytags
RUN go get github.com/josharian/impl
RUN go get github.com/davidrjenni/reftools/cmd/fillstruct
RUN go get github.com/godoctor/godoctor
RUN go get github.com/go-delve/delve/cmd/dlv
RUN go get github.com/stamblerre/gocode
RUN go get github.com/rogpeppe/godef
RUN go get golang.org/x/tools/cmd/goimports
RUN brew install golangci-lint

# Githooks settings
ENV GITHOOKS_REPO="/workspaces/githooks"
ENV GITHOOKS_BIN_DIR="/workspaces/githooks/githooks/bin"
