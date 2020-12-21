FROM golang:1.15.3-alpine

RUN apk add --no-cache git git-lfs bash

RUN git config --global user.email "githook@test.com" && \
    git config --global user.name "Githook Tests"

ADD ./ /var/lib/githooks/
ADD ./.git /var/lib/githooks/.git
RUN echo "Make test gitrepo to clone from ..." && \
    cd /var/lib/githooks && \
    rm -rf .git/hooks && \
    git remote rm origin && \
    git commit -a --allow-empty -m "Current test changes" && \
    git tag "v9.9.0+test" && \
    git commit -a --allow-empty -m "Empty for reset to trigger update" >/dev/null 2>&1 && \
    git tag "v9.9.1+test"

# Build binaries
RUN go get github.com/go-delve/delve/cmd/dlv
ENV GOPATH="/var/lib/githooks/githooks/.go"
ENV GOBIN="/var/lib/githooks/githooks/bin"
RUN cd /var/lib/githooks/githooks && ./clean.sh
RUN /var/lib/githooks/githooks/build.sh -tags "debug,mock,docker"
RUN cp /var/lib/githooks/githooks/bin/installer /var/lib/githooks/installer

RUN dlv debug --headless --listen=:2345 --log --api-version=2 /var/lib/githooks/githooks/bin/installer