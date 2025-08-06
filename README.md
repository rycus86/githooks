# Githooks

[![Build status](https://github.com/rycus86/githooks/actions/workflows/main.yml/badge.svg)](https://github.com/rycus86/githooks/actions/workflows/main.yml)
[![Coverage Status](https://coveralls.io/repos/github/rycus86/githooks/badge.svg?branch=master)](https://coveralls.io/github/rycus86/githooks?branch=master)

A simple Shell script to support per-repository [Git hooks](https://git-scm.com/docs/githooks), checked into the actual repository that uses them.

To make this work, it creates hook templates that are installed into the `.git/hooks` folders automatically on `git init` and `git clone`. When one of them executes, it will try to find matching files in the `.githooks` directory under the project root, and invoke them one-by-one. There's more to the story though, you can read about it under the [Templates or global hooks](#Templates-or-global-hooks) section.

> Check out the [blog post](https://blog.viktoradam.net/2018/07/26/githooks-auto-install-hooks/) for the long read!

## Go version

Thanks to [@gabyx](https://github.com/gabyx), this project has now been also ported over to Go in [gabyx/githooks](https://github.com/gabyx/githooks).
Check it out if you're after some extra features like parallel execution, automatic updates, GUI dialog integration, colored terminal output, and more...

## Layout and options

Take this snippet of a project layout as an example:

```
/
└── .githooks/
    └── commit-msg/
        ├── validate
        └── add-text
    └── pre-commit/
        ├── 01-validate
        ├── 02-lint
        ├── 03-test
        ├── docs.md
        └── .ignore
    └── post-checkout
    └── ...
    └── .ignore
    └── .shared
    └── .lfs-required
├── README.md
├── LICENSE
└── ...
```

All hooks to be executed live under the `.githooks` top-level folder, that should be checked into the repository. Inside, we can have directories with the name of the hook (like `commit-msg` and `pre-commit` above), or a file matching the hook name (like `post-checkout` in the example). The filenames in the directory do not matter, but the ones starting with a `.` will be excluded by default. All others are executed in alphabetical order according to the [glob / LC_COLLATE](http://pubs.opengroup.org/onlinepubs/007908775/xsh/glob.html) rules. You can use the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool as `git hooks list` to list all the hooks that apply to the current repository and their current state.

## Execution

If a file is executable, it is directly invoked, otherwise it is interpreted with the `sh` shell. All parameters of the hook are passed to each of the scripts.

Hooks related to `commit` events will also have a `${STAGED_FILES}` environment variable set, that is the list of staged and changed files (according to `git diff --cached --diff-filter=ACMR --name-only`), one per line and where it makes sense (not `post-commit`). If you want to iterate over them, and expect spaces in paths, you might want to set `IFS` like this.

```shell
IFS="
"
for STAGED in ${STAGED_FILES}; do
    ...
done
```

The `ACMR` filter in the `git diff` will include staged files that are added, copied, modified or renamed.

__Note__: if the list of changes is over 100k characters, then instead of `${STAGED_FILES}` you will get the `${STAGED_FILES_REFERENCE}` variable set instead which will point to a temporary file containing this list. This is to avoid `Argument list too long` errors when executing hooks and other parts of the framework. If you have a large enough repository where this is a concern, you should probably start your hook files by examining if this reference is set, like shown below.

```shell
if [ -n "${STAGED_FILES_REFERENCE}" ]; then
    STAGED_FILES="$(cat "${STAGED_FILES_REFERENCE}")"
fi

for STAGED in ${STAGED_FILES}; do
    ...
done
```

## Supported hooks

The supported hooks are listed below. Refer to the [Git documentation](https://git-scm.com/docs/githooks) for information on what they do and what parameters they receive.

- `applypatch-msg`
- `pre-applypatch`
- `post-applypatch`
- `pre-commit`
- `pre-merge-commit`
- `prepare-commit-msg`
- `commit-msg`
- `post-commit`
- `pre-rebase`
- `post-checkout`
- `post-merge`
- `pre-push`
- `pre-receive`
- `update`
- `post-receive`
- `post-update`
- `reference-transaction`
- `push-to-checkout`
- `pre-auto-gc`
- `post-rewrite`
- `sendemail-validate`
- `post-index-change`

The `fsmonitor-watchman` hook is currently not supported. If you have a use-case for it and want to use it with this tool, please open an issue.

## Git Large File Storage support

If the user has installed [Git Large File Storage](https://git-lfs.github.com/) (`git-lfs`) by calling
`git lfs install` globally or locally for a repository only, `git-lfs` installs 4 hooks when initializing (`git init`) or cloning (`git clone`) a repository:

- `post-checkout`
- `post-commit`
- `post-merge`
- `pre-push`

Since Githooks overwrites the hooks in `.git/hooks`, it will also run all *Git LFS* hooks internally if the `git-lfs` executable is found on the system path. You can enforce having `git-lfs` installed on the system by placing a `./githooks/.lfs-required` file inside the repository, then if `git-lfs` is missing, a warning is shown and the hook will exit with code `1`. For some `post-*` hooks this does not mean that the outcome of the git command can be influenced even tough the exit code is `1`, for example `post-commit` hooks can't fail commits. A clone of a repository containing this file might still work but would issue a warning and exit with code `1`, a push - however - will fail if `git-lfs` is missing.

It is advisable for repositories using *Git LFS* to also have a pre-commit hook (e.g. `examples/lfs/pre-commit`) checked in which enforces a correct installation of *Git LFS*.

## Ignoring files

The `.ignore` files allow excluding files from being treated as a hook script. They allow *glob* filename patterns, empty lines and comments, where the line starts with a `#` character. In the above example, one of the `.ignore` files should contain `*.md` to exclude the `pre-commit/docs.md` Markdown file. The `.githooks/.ignore` file applies to each of the hook directories, and should still define filename patterns, `*.txt` instead of `**/*.txt` for example. If there is a `.ignore` file both in the hook type folder and in `.githooks`, the files whose filename matches any pattern from either of those two files will be excluded. You can also manage `.ignore` files using the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool, and running `git hooks ignore <pattern>`.

Hooks in individual repositories can be disabled as well, running `git hooks disable ...`, or all of them with `git hooks config set disable`, check their documentation or `help` for more information. Finally, all hook execution can be bypassed with a non-empty value in the `$GITHOOKS_DISABLE` environment variable too.

## Shared hook repositories

The hooks are primarily designed to execute programs or scripts in the `.githooks` folder of a single repository. However there are use-cases for common hooks, shared between many repositories with similar requirements and functionality. For example, you could make sure Python dependencies are updated on projects that have a `requirements.txt` file, or an `mvn verify` is executed on `pre-commit` for Maven projects, etc.

For this reason, you can place a `.shared` file inside the `.githooks` repository, which can hold a list of repositories, one per line, which hold common and shared hooks. Alternatively, you can have a shared repositories set by multiple `githooks.shared` local or global Git configuration variables, and the hooks in these repositories will execute for all local projects where Githooks is installed. Below are example values for these setting.

```shell
$ git config --global --get-all githooks.shared # shared hooks in global config (for all repositories)
https://github.com/shared/hooks-python.git
git@github.com:shared/repo.git@mybranch
$ cd myrepo
$ git config --local --get-all githooks.shared # shared hooks in local config (for specific repository)
ssh://user@github.com/shared/special-hooks.git@v3.3.3
/opt/myspecialhooks
$ cat .githooks/shared
ssh://user@github.com/shared/special-hooks.git@otherbranch
$ git hooks shared list
...
```

The install script offers to set up shared hooks in the global Git config,
but you can do it any time by changing the global configuration variable.

Supported entries for shared hooks are:

- **All URLs [Git supports](https://git-scm.com/docs/git-clone#_git_urls)** such as:

  - `ssh://github.com/shared/hooks-maven.git@mybranch` and also the short `scp` form
     `git@github.com:shared/hooks-maven.git`
  - `git://github.com/shared/hooks-python.git`
  - `file:///local/path/to/bare-repo.git@mybranch`

  All URLs can include a tag specification syntax at the end like `...@<tag>`, where `<tag>` is a Git tag, branch or commit hash.
  The `file://` protocol is treated the same as a local path to a bare repository, see *local paths* below.

- **Local paths** to bare and non-bare repositories such as:

  - `/local/path/to/checkout` (gets used directly)
  - `/local/path/to/bare-repo.git` (gets cloned internally)

  Note that relative paths are relative to the path of the repository executing the hook.
  These entries are forbidden for **shared hooks** configured by `.githooks/.shared` per repository
  because it makes little sense and is a security risk.

Shared hooks repositories specified by *URLs* and *local paths to bare repository* will be checked out into the `<install-prefix>/.githooks/shared` folder (`~/.githooks/shared` by default), and are updated automatically after a `post-merge` event (typically a `git pull`) on any local repositories. Any other local path will be used **directly and will not be updated or modified**.
Additionally, the update can also be triggered on other hook names by setting a comma-separated list of additional hook names in the Git configuration parameter `githooks.sharedHooksUpdateTriggers` on any configuration level.

The layout of these shared repositories is the same as above, with the exception that the hook folders (or files) can be at the project root as well, to avoid the redundant `.githooks` folder.

An additional global configuration parameter `githooks.failOnNonExistingSharedHooks` makes hooks fail with an error if any shared hook configured in `.shared` is missing, meaning `git hooks update` has not yet been called. See `git hooks config [enable|disable] fail-on-non-existing-shared-hooks` in the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool documentation for more information.
Note that shared hooks are automatically updated on clone.

You can also manage and update shared hook repositories using the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool. Run `git hooks shared help` or see the tool's documentation in the `docs/` folder to see the available options.

## Opt-in hooks

To try and make things a little bit more secure, Githooks checks if any new hooks were added we haven't run before, or if any of the existing ones have changed. When they have, it will prompt for confirmation whether you accept those changes or not, and you can also disable specific hooks to skip running them until you decide otherwise. The accepted checksums are maintained in the `.git/.githooks.checksum` file, per local repository.

If the repository contains a `.githooks/trust-all` file, it is marked as a trusted repository. On the first interaction with hooks, Githooks will ask for confirmation that the user trusts all existing and future hooks in the repository, and if they do, no more confirmation prompts will be shown. This can be reverted by running either the `git config --unset githooks.trust.all`, or the `git hooks config reset trusted` command. This is a per-repository setting. These can be set up and changed with the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool as well, run `git hooks trust help` and `git hooks config help` for more information.

If a global shared hook repository contains a `.githooks/trust-all` file, the user can decide whether to trust them automatically. When adding a shared hook repository for the first time, Githooks will ask for confirmation that the user trusts all existing **and future** hooks in the repository, and if they do, no more confirmation prompts will be shown. This can be reverted by running either the `git config --global --unset githooks.trust.all`. This is a global setting. These can be set up and changed with the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool as well, run `git hooks trust help` for more information.

There is a caveat worth mentioning: if a terminal *(tty)* can't be allocated, then the default action is to accept the changes or new hooks. Let me know in an issue if you strongly disagree, and you think this is a big enough risk worth having slightly worse UX instead.

You can also accept changes to a hook using the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool, and running `git hooks accept <hook>`. See the tool's documentation in the `docs/` folder to see the available options.

### Opt-out

In a similar spirit to the opt-in above, you can also opt-out of running the hooks in the repository. You can disable executing the files per project, or globally, using the commands below.

```shell
# Disable in the current repository
$ git hooks config set disable
$ git config githooks.disable true  # alternative
# Disable in all repositories
$ git config --global githooks.disable true
```

Also, as mentioned above, all hook execution can be bypassed with a non-empty value in the `$GITHOOKS_DISABLE` environment variable, or per-repository, by running the `git hooks config set disable` command.

You can also selectively disable some or all of the hooks using the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool, and running `git hooks disable <hook>`. See the tool's documentation in the `docs/` folder to see the available options.

## Command line helper

Githooks will set up a Git alias for `git hooks <cmd>` for you, that enables you to print the names and state of the hooks in the current repository, and also manage them, along with some other functionality, like updating shared hook repositories, running a Githooks update, etc.

> See the documentation of the command line helper tool on its [docs page](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md)!

## Installation

The commands below fetch and execute the [install.sh](install.sh) script from this repository. It will:

1. Find out where the Git templates directory is
    1. From the `$GIT_TEMPLATE_DIR` environment variable
    2. With the `git config --get init.templateDir` command
    3. Checking the default `/usr/share/git-core/templates` folder
    4. Search on the filesystem for matching directories
    5. Offer to set up a new one, and make it `init.templateDir`
2. Set up the hook templates for the supported hooks - the templates are basically a copy of the `base-template.sh` file content
3. Offer to enable automatic update checks
4. Offer to find existing Git repositories on the filesystem (disable with `--skip-install-into-existing`)
    1. Install the hooks into them
    2. Offer to add an intro README in their `.githooks` folder
5. Offer to set up shared hook repositories

To install the templates, just execute the command below, and follow the instructions in the terminal.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)"
```

If you want, you can try out what the script would do first, without changing anything.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --dry-run
```

You can also run the installation in non-interactive mode with the command below. This will determine an appropriate template directory (detect and use the existing one, or use the one passed by `--template-dir`, or use a default one), install the hooks automatically into this directory, and enable periodic update checks.

The global install prefix defaults to `${HOME}` but can be changed by passing `--prefix <install-prefix>` to the `install.sh` script.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --non-interactive
```

There is also an option to run the install script for the repository in the current directory only. For this, run the command below.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --single
```

It's possible to specify which template directory should be used, by passing the `--template-dir <dir>` parameter, where `<dir>` is the directory where you wish the templates to be installed.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --template-dir /home/public/.githooks
```

By default the script will install the hooks into the `~/.githooks/templates/` directory.

Lastly, you have the option to install the templates to, and use them from a centralized location. You can read more about the difference between this option and default one [below](#Templates-or-global-hooks). For this, run the command below.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --use-core-hookspath
```

Optionally, you can also pass the template directory to which you want to install the centralized hooks by appending `--template-dir <path>` to the command above, for example:

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --use-core-hookspath --template-dir /home/public/.githooks
```

If you want to install from another repository (e.g. from your own fork), you can specify the update repository url as well as the branch name (default: `master`) when installing with:

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --clone-url "https://server.com/my-githooks-fork.git" --clone-branch "release"
```

This will be then used for installation and further updates.

Finally, if you trust GitHub URLs more, use the command below that skips the redirect from `r.viktoradam.net`. Also, some corporate proxies are not in favour of my Cloudflare certificates for some reason, so you might have a better chance with GitHub links in this case.

```shell
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/rycus86/githooks/master/install.sh)"
```

The GitHub URL also accepts the additional parameters mentioned above, the `https://r.viktoradam.net/githooks` URL is just a redirect to the longer GitHub address.

### Install on the server

On a server infrastructure where only *bare* repositories are maintained, it is best to maintain only server hooks.
This can be achieved by installing with the additional flag `--only-server-hooks` by:

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --only-server-hooks
```

The global template directory then **only** maintain contains the following server hooks:

 - `pre-push`
 - `pre-receive`
 - `update`
 - `post-receive`
 - `post-update`
 - `push-to-checkout`
 - `pre-auto-gc`

which get deployed with `git init` or `git clone` automatically.
See also the [setup for bare repositories](#setup-for-bare-repositories).

### Setup for bare repositories

Because bare repositories mostly live on a server, you should setup the following:
```shell
cd bareRepo
# Install Githooks into this bare repository
# which will only install server hooks:
git hooks install
# Creates .githooks/trust-all marker for this bare repo
git hooks trust
# Automatically accept changes to all existing and new
# hooks in the current repository.
git hooks config accept trusted
# Don't do global automatic updates, since the Githooks update
# script should not be run in parallel on a server.
git hooks config disable update
```

Githooks updates in *bare* repositories will only update server hooks as described in the [install section](#install-on-the-server)

### Templates or global hooks

This script can work in one of 2 ways:

- Using the git template folder (default behavior)
- Using the git `core.hooksPath` variable (set by passing the `--use-core-hookspath` parameter to the install script)

Read about the differences between these 2 approaches below.

In both cases, the script will make sure git finds the hook templates provided by this script.
When one of them executes, it will try to find matching files in the `.githooks` directory under the project root, and invoke them one-by-one.

#### Template folder

In this approach, the install script creates hook templates that are installed into the `.git/hooks` folders automatically on `git init` and `git clone`. For bare repositories, the hooks are installed into the `./hooks` folder on `git init --bare`.

This is the recommended approach, especially if you want to selectively control which repositories use these scripts. The install script offers to search for repositories to which it will install the hooks, and any new repositories you clone will have these hooks configured.

#### Central hooks location (core.hooksPath)

In this approach, the install script installs the hook templates into a centralized location (`~/.githooks/templates/` by default) and sets the global `core.hooksPath` variable to that location. Git will then, for all relevant actions, check the `core.hooksPath` location, instead of the default `${GIT_DIR}/hooks` location.

This approach works more like a *blanket* solution, where __all repositories__ (\*) will start using the hook templates, regardless of their location.

**Note**(\*): It is possible to override the behavior for a specific repository, by setting a local `core.hooksPath` variable with value `${GIT_DIR}/hooks`, which will revert git back to its default behavior for that specific repository.

### Required tools

Although most systems will usually have these tools (especially if you're using Git), I should mention that the project assumes the following programs to be available:

- `git`
- `awk`
- `sed`
- `grep`
- `find`

### Updates

You can update the scripts any time by running one of the install commands above. It will simply overwrite the templates with the new ones, and if you opt-in to install into existing local repositories, those will get overwritten too.

You can also enable automatic update checks during the installation, that is executed once a day after a successful commit. It downloads the latest version of the install script, and asks whether you want to install it. Automatic updates can be enabled or disabled at any time by running the command below.

```shell
# enable with either:
$ git hooks update enable
$ git config --global githooks.autoupdate.enabled true
# disable with either:
$ git hooks update disable
$ git config --global githooks.autoupdate.enabled false
$ git config --global --unset githooks.autoupdate.enabled
```

You can also check for updates at any time by executing `git hooks update`, using the [command line helper](https://github.com/rycus86/githooks/blob/master/docs/command-line-tool.md) tool. You can also use its `git hooks config [enable|disable] update` command to enable or disable the automatic update checks.

### Custom user prompt

If you want to use a GUI dialog when Githooks asks for user input, you can use an executable or script file to display it.
The example in the `examples/tools/dialog` folder contains a Python script `run` which uses the Python provided `tkinter` to show a dialog.

```shell
# install the example dialog tool from this repository
$ git hooks tools register dialog "./examples/tools/dialog"
```

This will copy the tool to a centrally managed folder to execute when displaying user prompts.
The tool's interface is as follows.

```shell
$ run <title> <text> <options> <long-options>    # if `run` is executable
$ sh run <title> <text> <options> <long-options> # otherwise, assuming `run` is a shell script
```

The arguments for the dialog tool are:

- `<title>` the title for the GUI dialog
- `<text>` the text for the GUI dialog
- `<short-options>` the button return values, separated by slashes, e.g. `Y/n/d`. The default button is the first capital character found.
- `<long-options>` the button texts in the GUI, e.g. `Yes/no/disable`

The script needs to return one of the short-options on the standard output.
If the exit code is not `0`, the normal prompt on the standard input is shown as a fallback mechanism.

### Uninstalling

If you want to get rid of these hooks and templates, you can execute the `uninstall.sh` script similarly to the install scripts.

```shell
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/rycus86/githooks/master/uninstall.sh)"
```

This will delete the template files, optionally the installed hooks from the existing local repositories, and reinstates any previous hooks that were moved during the installation.

## Acknowledgements

These two projects gave some ideas and inspiration, you should check them out:

- [git-hooks/git-hooks](https://github.com/git-hooks/git-hooks) - written in Go
- [icefox/git-hooks](https://github.com/icefox/git-hooks) - written in Bash

## License

MIT
