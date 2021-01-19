#!/bin/sh
DIR="$(cd "$(dirname "$0")" && pwd -W)"
REPO_DIR="$DIR/.."

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

WORKDIR C:/githooks
EOF

docker run -a stdout -a stderr -v "$REPO_DIR:C:\githooks" \
    "githooks:windows-lfs-go" \
    "C:\Program Files\Git\bin\sh.exe" \
    "C:/githooks/tests/exec-tests-windows-go.sh" "$@"
RESULT=$?

docker rmi "githooks:$IMAGE_TYPE"
docker rmi "githooks:$IMAGE_TYPE-base"
exit $RESULT
