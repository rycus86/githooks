FROM golang:1.15.6-alpine
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000

# Setup user
RUN adduser $USERNAME -s /bin/sh -D -u $USER_UID $USER_GID && \
    mkdir -p /etc/sudoers.d && \
    echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME && \
    chmod 0440 /etc/sudoers.d/$USERNAME

# Add dependencies.
RUN apk add git git-lfs --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/main --allow-untrusted
RUN apk add bash curl gnupg
RUN apk add -q --update --progress --no-cache sudo openssh-client zsh

USER root

# # Add linux brew.
# RUN mkdir -p /home/linuxbrew
# RUN chown -R vscode:vscode  /home/linuxbrew
# RUN /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
# ENV PATH=/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH
# RUN echo "eval \$($(brew --prefix)/bin/brew shellenv)" >>~/.zshrc
# RUN brew install shfmt shellcheck
# RUN rm -rf ~/.cache

# Add zsh shell setup.
RUN apk add perl ncurses
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
RUN curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b $(go env GOPATH)/bin v1.34.1

# Shellcheck and shellformat
RUN curl -fsSL https://github.com/mvdan/sh/releases/download/v3.1.1/shfmt_v3.1.1_linux_amd64 -o /usr/local/bin/shfmt \
    && chmod +x /usr/local/bin/shfmt \
    && shfmt --version
RUN T=$(mktemp); curl -fsSL https://github.com/koalaman/shellcheck/releases/download/v0.7.1/shellcheck-v0.7.1.linux.x86_64.tar.xz -o "$T" \
    && tar -xf "$T" --strip-components=1 -C /usr/local/bin/ \
    && chmod +x /usr/local/bin/shellcheck \
    && shellcheck --version

# Githooks settings
ENV GITHOOKS_REPO="/workspaces/githooks"
ENV GH_TEST_BIN="/workspaces/githooks/githooks/bin"

RUN chown -R vscode:vscode "$GOPATH"
USER vscode