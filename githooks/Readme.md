# Rewrite in Go

## Test Debugging

Execute:

```shell
    ./build.sh && ./test.sh
```

## Deprecated Stuff

1. Registered file becomse a JSON file -> (@todo needs legacy transform)
2. Ignore patterns matched only filename. @Todo: Ignore patterns are matching the paths relative to the

    - Git dir. for old hook: `hooks/pre-commit.replaced.githook`
    - `[<namespace>/]pre-commit/monkey.sh` e.g. for shared hooks.

Namespace `<namespace>` can be defined in shared hooks in a file `.namespace`. Default is empty.
3. `githooks.trust.all` move to `githooks.trustAll` @todo
4. Checksum file should not contain, disabled settings as well. There is a bug in `execute_opt_in_checks`: disabling hooks only works if repo `! is_trusted_repo`.
We store this in `.git/.githooks.ignored.yaml`
5. The following ignore files will exist in a repo:
    - Worktree `.githooks/.ignored.yaml`
    - User `.git/.githooks.ignored.yaml`
5. For shared hooks we define the repo as the `.githooks` folder and `<sharedRoot>/.githooks` is no more considerd to collect hooks from, since it enables the use of githooks in hooks repositories. (@todo Needs legacy transform)
5. For shared repos only `<sharedRoot>/.ignored.yaml` is considered for ignoring (new feature)
5. Default runner on Unix is `sh` and on Windows its `sh -c` since
there is no notion of execution permissions and this honors the shebang correctly.

## Problems

- How to get the controlling terminal on Windows? Since we launch through the wrapper git-bash.exe anyway -> /dev/tty is available ? Probably not.
  - Solved: see `ctty-windows.go` which works.