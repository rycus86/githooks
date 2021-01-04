# Githooks v2.0

## Test Debugging

Test run:

```shell
cd githooks
./build.sh && ./test.sh
```

Run tests:

```shell
sh tests/exec-tests-go.sh {001..120}
```

## Debugging in Dev Container

There is a docker development container for debugging purposes in `.devcontainer`. VS Code can be launched in this remote docker container with the extension `ms-vscode-remote.remote-containers`.
Use ``Remote-Containers: Open Workspace in Container...` and `Remote-Containers: Rebuild Container`.

Once in the development container: You can launch the VS Code tasks:

- `[Dev Container] go-delve-installer`

which will start the `delve` debugger headless as a server in a terminal. You can then attach to the debug server with the debug configuration `Debug Go [remote delve]`. Set breakpoints in the source code to trigger them

## New and Deprecated Stuff

So far we comply 99% to the original implementation. Internally we wrap legacy stuff such that we agree the most with the original implementation. The following summarizes the new features and gives rational about why we deprecate other behavior.

Notation: The repository path where we currently execute the runner is denoted by `<repo>`. A shared hook repo path is denoted by `<sharedRepo>`. The install folder is denoted by `<installDir>`.

### Register File

1. It becomes a YAML file: **[done]**

    - @todo remove legacy load/store of old file `registered`. **[done]**
    - if backwards compatible: needs legacy transform in installer. *[not yet done]*

### Shared Hook Repo Format

1. Shared hook repos may only contain hooks in their root dir of the repository (which will be defined as the their specific `.githooks` folder).
That way shared hook repos can also have hooks `<sharedRepo>/.githooks/...` which will be executed, when working with these repos.
But are ignored when pulled in by other hook execution: **[done]**

2. Maybe add a format version number (e.g. `2.0`) in `<sharedRepo>/.githooks.yaml`: *[not done]*

    ```yaml
    layout: "2.0" # Layout of the shared hook repo.
    version: "1.9.1" # The version number of the hooks.
    ```
### Shared File Specs

1. The `.githooks/.shared` is turned into `./.githooks/.shared.yaml` **[done]** (still to depercate old)

### Ignore Patterns

1. All ignore files become YAML files `.ignore.yaml`: **[done]**

    - no backward compatible: either legacy transform any files in installer or
    - still support old ignore files `.ignore` (parse) by runner, CLI will however write YAML. **[done]**

2. Ignore files locations are: **[done]**

    1. **User Ignores**

        - `<repo>/.git/.githooks.ignore.yaml`

    2. **Repository Ignores**

        - `<repo>/.githooks/.ignore.yaml` [
        - `<repo>/.githooks/<hookName>/.ignore.yaml`
        - `<sharedRepo>/.ignore.yaml`
        - `<sharedRepo>/<hookName>/.ignore.yaml`

    All these are respected when collecting hooks, either locally in `<repo>` or `<sharedRepo>`s.

3. Ignore patterns are matching a relative path of the hook.
   Before only the file name was matched. To make it more flexible, we match ignore patterns against
   `[<nameSpace>/]<relPath>` where `<relPath>` is the relative path of the hook *[not yet finished]*

    - relative to `<repo>/.githooks` in case of **repo hooks**, optional `<namespace>` is
      read from `<repo>/.githooks/.namespace`.
    - relative to `<sharedRepo>` where namespace is read from `<sharedRepo>/.namespace` in case of **shared hooks**
    - relative to the Git directory (e.g `<repo>/.git`, or where ever it is located)
      for **replaced hooks**. e.g `hooks/pre-commit.replaced.githook`. `<namespace>` is empty.

    Namespacing is intended because in that way one can easily distinguish between hooks from different shared hook repos
    inside the ignore file (and possible for other use cases).

4. Replaced hooks can no more be ignored by worktree ignores `.githooks/.ignore[.yaml]`. Rational: They are inside the `.git/hooks`
folder and have nothing to do with checked in hooks and their ignores. They can only be ignored by user ignores in
`.git/.githooks.ignore.yaml` **[done]**

5. Disabling hooks will no more be stored in the `.githooks.checksum` but rather as a **user ignore** in `<repo>/.git/.githooks.ignore.yaml`.

    - @todo remove legacy store/load from old location.
    - changes in CLI *[not done]*

### Trusting and Checksums

1. Trust file becomes a YAML file. **[done]**

    - @todo remove legacy store/load from old location
    - no backward compatibility, since it just means -> retrusting hooks.

2. A new checksum cache mechanism is implemented which has search directories
   (and bucktes like in git `.git/objects` directory) which are
   considered to look for a checksum files where the filename
   is the SHA1 hash of the hook which was
   trusted, e.g. **[done]**

    ```shell
    checksums
     └── 95
          ├──ccf7e150318102b64317533ea514da91034ac0
          └──8d/0293ff5573b5dd2b6ae1fac24c3acdd7679
     └── 6e
          └──3011833858f525923627da0d8b76a3ce700f0d
     └── 12
          └──c2d1d3d2c91bcceb76415fe7fdad8345a6598e
    ```

    Each checksum file contains also the `<namespace>/<relPath>` of the
    hook it belongs to, in case it is needed (?). *[not done]*

3. Checksums should be stored as SHA1 filenames (as described above) in

    - the directory specified in the global Git config `githooks.checksumCacheDir` or if not existing (can be made `<installDir>/checksums` during install)
    - the directory `<repo>/.git/.githooks.checksums`.

This is more efficient, since we only have to search for such a file and we know we have trusted this hook. Instead of parsing the file for every hook run. Note: `git commit` runs several hooks, and all need to re-read the same stuff again.

4. Move config `githooks.trust.all` to `githooks.trust.all`. **[done]**

### Hook Runner

1. Each hook can have a file `<hookName>.runner` next to it which is read and can define the run command whith which this hook is launched: **[done]**

    *`pre-commit.runner`* may contain:

    ```shell
    /bin/env/myexecutable -g -m -z 'ass' -r "bla bla" --file
    ```

    which is parsed by `https://godoc.org/github.com/google/shlex`.

    - Substitute over all args all environment variables in `sh` style. **[done, test 121]**

2. Default runner on Unix is `sh` and on Windows its `sh -c` since
there is no notion of execution permissions and this
honors the shebang correctly. **[done]**

### Parallel Execution

All hooks to execute, except the old replaced hook, are already collected and afterwards executed. As we use a threadpool, one can now
support executing hooks in parallel. **[done]**

One might have several successive parallel batches for each type:

- local repository hooks in `<repoPath>/.githooks/<hookName>/...`

  - batch 1
  - ...
  - batch N

- each collected shared hooks in `<repoPath>/.githooks/<hookName>...`

  - batch 1
  - ...
  - batch N

This however poses the question: How should we define these batches?
Should we have folders e.g. `<sharedRepo>/.githooks/<hookName>`: *[not done]*

```shell
└── batch 1
    ├── hook a
    └── hook b
└── batch 2
    └── hook c
└── batch 3
    └── hook d
    └── hook e
    └── hook f
...
```

Or should we put that configuration stuff inside `<sharedRepo>/.githooks/<hookName>/parallel.yaml`.

- Support the `batch <N>` folders. (easy and with no implementation cost) *[not finished yet]*
- Support the configuration over a `parallel.yaml` if it exists it the first choice. *[not done]*

There is also the question of should have a notion of read-only (no changes to the filesystem) and read-write (changes may happen to the filesystem) hooks. With the above pattern there is a impleizit synchronization point between `.githooks` folder (which is ok and good). But can we do better? Can we merge stuff if the user specifies that in the `parallel.yaml` somehow?

## Installer

### Update Procedure

Updating might work like the following when the installer enters (`if ! is_postupdate`):

- If the remote branch **cannot** be merged (only test it, this happens later) or fast-forwarded into the local branch -> exit gracefully with error. **[done]** (in runner)

- Otherwise, clone the remote branch in the release folder into a temporary dir.

- Get the binares either by manually building or by calling a
  binary download tool (analoguous to the dialog tool) which
  provides the binaries for the system:
	 - Arguments: current commit sha.
     - Returns: `installer`, `runner`, `cli`"
	 - Binaries should be signed: https://github.com/kencochrane/golang-github-action-sign-macos/

  If we use [https://goreleaser.com](https://goreleaser.com]) we directly check the deploy url as the default behavior.
  if the download of the binaries fails, or cannot be verified... (how? app sigining... argh -> later)
  or the binary are not yet built (can happen) -> the installer gracefully exits
  leaving the remote branch where it was -> the update will be postponed till the next trigger...

- When the binaries are succesfully downloaded & verified, we dispatch to the **downloaded** installer (with `--internal-install-postupdate`). It then continues to the postupdate install procedure as follows.

- It replaces the current binaries with the downloaded (needs to be provided on the command line)
  -> needs special care for Windows when the `cli`/`runner` or `installer` is still running [see here]([https://www.codeproject.com/Questions/621666/Download-and-replace-running-EXE#:~:text=If%20the%20exe%20is%20running,after%2).
- Update all stuff it needs to do (as in `base-template.sh`) ... including legacy transforms
  - Initialy we drop all legacy shit for the go
    rewrite, to start fresh... but this feature needs to be included in the design since we want nice update compatibility from old releases in the future. -> Refactor this part out, such that it does not clutter the normal procedure.
- It then updates the last update time.
- Exits with `0` -> **Update completed.**


## Todos

When installer is finished for testing:

- // @todo installer: remove "--internal-install" in runner. it needs to launch the normal one first...
- calling cli.sh (cli executable) is inappropriate, -> share functionality already in runner.

## Problems

- How to get the controlling terminal on Windows? Since we launch through the wrapper git-bash.exe anyway -> /dev/tty is available ? Probably not.
  - Solved: see `ctty-windows.go` which works.