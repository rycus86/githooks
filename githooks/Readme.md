# Rewrite in Go

## Test Debugging

Execute:

```shell
    ./build.sh && ./test.sh
```

## Deprecated Stuff

1. registered file becomse a JSON file -> legacy transform
2. Ignore patterns matched only filename. Now , ignore patterns are matching the paths relative to the

    - Git dir. for old hook `hooks/pre-commit.replaced.githook`
    - `.githooks/<namespace>/` for shared hooks with a `.githooks` folder
    - `<namespace>/` for shared hooks without a `.githooks` folder.

Namespace `<namespace>` can be defined in shared hooks in a file `.namespace`. Default is empty.
3. TODO: `githooks.trust.all` move to `githooks.trustAll`
4. Checksum fileR should not contain, disabled settings as well. There is a bug in `execute_opt_in_checks`: disabling hooks only works if repo `! is_trusted_repo`.
We store this in `.git/.githooks.disabled`
5. Default runner on Unix is `sh` and on Windows its `sh -c` since
there is no notion of execution permissions and this honors the shebang correctly.

## Problems

- How to get the controlling terminal on Windows? Since we launch through the wrapper git-bash.exe anyway -> /dev/tty is available ? Probably not.
  - Solved: see `ctty-windows.go` which works.