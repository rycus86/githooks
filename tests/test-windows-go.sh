#!/bin/sh

cat <<'EOF' | docker build --force-rm -t githooks:windows-lfs-go -f - .
FROM mcr.microsoft.com/windows/servercore:1809

# $ProgressPreference: https://github.com/PowerShell/PowerShell/issues/2138#issuecomment-251261324
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

RUN iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
RUN choco install -y git

# ideally, this would be C:\go to match Linux a bit closer, but C:\go is the recommended install path for Go itself on Windows
ENV GOPATH C:\\gopath

# PATH isn't actually set in the Docker image, so we have to set it from within the container
RUN $newPath = ('{0}\bin;C:\go\bin;{1}' -f $env:GOPATH, $env:PATH); \
    Write-Host ('Updating PATH: {0}' -f $newPath); \
    [Environment]::SetEnvironmentVariable('PATH', $newPath, [EnvironmentVariableTarget]::Machine);
# doing this first to share cache across versions more aggressively

ENV GOLANG_VERSION 1.15.6

RUN $url = 'https://storage.googleapis.com/golang/go1.15.6.windows-amd64.zip'; \
    Write-Host ('Downloading {0} ...' -f $url); \
    $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest -Uri $url -OutFile 'go.zip'; \
    \
    $sha256 = 'b7b3808bb072c2bab73175009187fd5a7f20ffe0a31739937003a14c5c4d9006'; \
    Write-Host ('Verifying sha256 ({0}) ...' -f $sha256); \
    if ((Get-FileHash go.zip -Algorithm sha256).Hash -ne $sha256) { \
        Write-Host 'FAILED!'; \
        exit 1; \
    }; \
    \
    Write-Host 'Expanding ...'; \
    $ProgressPreference = 'SilentlyContinue'; Expand-Archive go.zip -DestinationPath C:\; \
    \
    Write-Host 'Removing ...'; \
    Remove-Item go.zip -Force; \
    \
    Write-Host 'Verifying install ("go version") ...'; \
    go version; \
    \
    Write-Host 'Complete.';


ENV GH_TESTS="c:/githooks-tests/tests"
ENV GH_TEST_TMP="c:/githooks-tests/tmp"
ENV GH_TEST_REPO="c:/githooks-tests/githooks"
ENV GH_TEST_BIN="c:/githooks-tests/githooks/githooks/bin"
ENV GH_TEST_GIT_CORE="c:/Program Files/Git/mingw64/share/git-core"

# Add sources
COPY githooks "$GH_TEST_REPO/githooks"
ADD .githooks/README.md "$GH_TEST_REPO/.githooks/README.md"
ADD examples "$GH_TEST_REPO/examples"
ADD tests "$GH_TESTS"

RUN & "'C:/Program Files/Git/bin/sh.exe'" "C:/githooks-tests/tests/test-windows-setup.sh"
WORKDIR C:/githooks-tests/tests
EOF

docker run --rm \
    -a stdout \
    -a stderr "githooks:windows-lfs-go" \
    "C:/Program Files/Git/bin/sh.exe" ./exec-steps-go.sh --skip-docker-check "$@"

RESULT=$?

docker rmi "githooks:windows-lfs-go"
exit $RESULT
