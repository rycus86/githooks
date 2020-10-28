# Rewrite in Go

## Test Debugging

Execute:

```shell
    ./build.sh && ./test.sh
```

## Deprecated Stuff

This stuff is to be made deprecated once all tests are passing. So far we comply 99% to the original implementation. Internally we wrap legacy stuff such that we agree the most with the original implementation.

1. Registered file becomse a JSON file -> (@todo needs legacy transform)
2. Ignore patterns matched only filename. @Todo: Ignore patterns are matching the paths relative to the

    - Git dir. for old hook: `hooks/pre-commit.replaced.githook`
    - `[<namespace>/]pre-commit/monkey.sh` e.g. for shared hooks.

    Namespace `<namespace>` can be defined in shared hooks in a file `.namespace`. Default is empty.
3. Replaced hooks can no more be ignored by worktree ignores `.githooks/.ignore[.yaml]`. Rational: They are inside the `.git/hooks`
folder and have nothing to do with checked in hooks and their ignores. They can only be ignored by user ignores in
`.git/.githooks.ignore.yaml`
4. Checksum file should not contain, disabled settings as well. There is a bug in `execute_opt_in_checks`: disabling hooks only works if repo `! is_trusted_repo`.
We store this in `.git/.githooks.ignore.yaml`
5. The following ignore files will exist in a repo:
    - Worktree `.githooks/.ignore.yaml`
    - User `.git/.githooks.ignore.yaml`
5. For shared hooks we define the repo as the `.githooks` folder and `<sharedRoot>/.githooks` is no more considerd to collect hooks from, since it enables the use of githooks in hooks repositories. (@todo Needs legacy transform)
5. For shared repos only `<sharedRoot>/.ignore.yaml` is considered for ignoring (new feature)
5. Default runner on Unix is `sh` and on Windows its `sh -c` since
there is no notion of execution permissions and this honors the shebang correctly.

## Todos
1. `githooks.trust.all` move to `githooks.trustAll` @todo


## Problems

- How to get the controlling terminal on Windows? Since we launch through the wrapper git-bash.exe anyway -> /dev/tty is available ? Probably not.
  - Solved: see `ctty-windows.go` which works.