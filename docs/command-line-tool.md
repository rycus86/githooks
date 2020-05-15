# Command line helper

- [disable](#git-hooks-disable)
- [enable](#git-hooks-enable)
- [accept](#git-hooks-accept)
- [trust](#git-hooks-trust)
- [list](#git-hooks-list)
- [shared](#git-hooks-shared)
- [install](#git-hooks-install)
- [uninstall](#git-hooks-uninstall)
- [update](#git-hooks-update)
- [readme](#git-hooks-readme)
- [ignore](#git-hooks-ignore)
- [config](#git-hooks-config)
- [tools](#git-hooks-tools)
- [version](#git-hooks-version)
- [help](#git-hooks-help)

The `git hooks <cmd>` command line helper provides a convenience utility to manage Githooks configuration, hook files and other related functionality. The [cli.sh](https://github.com/rycus86/githooks/blob/master/cli.sh) script should be an alias for `git hooks`, which is done automatically by the install script with the `git config --global alias.hooks "!${SCRIPT_DIR}/githooks"` command.

See the list of available subcommands below, or run `git hooks help` locally.

## git hooks disable

Disables a hook in the current repository.

```shell
$ git hooks disable [--shared] [trigger] [hook-script]
$ git hooks disable [--shared] [hook-script]
$ git hooks disable [--shared] [trigger]
$ git hooks disable [-a|--all]
$ git hooks disable [-r|--reset]
```

Disables a hook in the current repository. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to disable, or its relative path, or an absolute path, we will try to find it. If the `--shared` parameter is given as the first argument, hooks in the shared repositories will be disabled, otherwise they are looked up in the current local repository. The `--all` parameter on its own will disable running any Githooks in the current repository, both existing ones and any future hooks. The `--reset` parameter is used to undo this, and let hooks run again. This command needs to be run at the root of a repository.

## git hooks enable

Enables a previously disabled hook in the current repository.

```shell
$ git hooks enable [--shared] [trigger] [hook-script]
$ git hooks enable [--shared] [hook-script]
$ git hooks enable [--shared] [trigger]
```

Enables a hook or hooks in the current repository. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to enable, or its relative path, or an absolute path, we will try to find it. This command needs to be run at the root of a repository. If the `--shared` parameter is given as the first argument, hooks in the shared repositories will be enabled, otherwise they are looked up in the current local repository.

## git hooks accept

Accept the pending changes of a new or modified hook.

```shell
$ git hooks accept [--shared] [trigger] [hook-script]
$ git hooks accept [--shared] [hook-script]
$ git hooks accept [--shared] [trigger]
```

Accepts a new hook or changes to an existing hook. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to enable, or its relative path, or an absolute path, we will try to find it. This command needs to be run at the root of a repository. If the `--shared` parameter is given as the first argument, hooks in the shared repositories will be accepted, otherwise they are looked up in the current local repository.

## git hooks trust

Manage settings related to trusted repositories.

```shell
$ git hooks trust
$ git hooks trust [revoke]
$ git hooks trust [delete]
$ git hooks trust [forget]
```

Sets up, or reverts the trusted setting for the local repository. When called without arguments, it marks the local repository as trusted. The `revoke` argument resets the already accepted trust setting, and the `delete` argument also deletes the trusted marker. The `forget` option unsets the trust setting, asking for accepting it again next time, if the repository is marked as trusted. This command needs to be run at the root of a repository.

## git hooks list

Lists the active hooks in the current repository.

```shell
$ git hooks list [type]
```

Lists the active hooks in the current repository along with their state. If `type` is given, then it only lists the hooks for that trigger event. This command needs to be run at the root of a repository.

## git hooks shared

Manages the shared hook repositories set either globally, or locally within the repository.

```shell
$ git hooks shared [add|remove] [--global|--local] <git-url>
$ git hooks shared clear [--global|--local|--all]
$ git hooks shared purge
$ git hooks shared list [--global|--local|--all] [--with-url]
$ git hooks shared [update|pull]
```

The `add` or `remove` subcommands adds or removes an item, given as `git-url` from the list. If `--global` is given, then the `githooks.shared` global Git configuration is modified, or if the `--local` option (default) is set, the `.githooks/.shared` file is modified in the local repository.

The `clear` subcommand deletes every item on either the global or the local list, or both when the `--all` option is given. The `purge` subcommand deletes the shared hook repositories already pulled locally.

The `list` subcommand list the global, local or all (default) shared hooks repositories, and optionally prints the Git URL for them, when the `--with-url` option is used.

The `update` or `pull` subcommands update all the shared repositories, both global and local, either by running `git pull` on existing ones or `git clone` on new ones.

## git hooks install

Installs the latest Githooks hooks.

```shell
$ git hooks install [--global]
```

Installs the Githooks hooks into the current repository. If the `--global` flag is given, it executes the installation globally, including the hook templates for future repositories.

## git hooks uninstall

Uninstalls the Githooks hooks.

```shell
$ git hooks uninstall [--global]
```

Uninstalls the Githooks hooks from the current repository. If the `--global` flag is given, it executes the uninstallation globally, including the hook templates and all local repositories.

## git hooks update

Performs an update check.

```shell
$ git hooks update [force]
$ git hooks update [enable|disable]
```

Executes an update check for a newer Githooks version. If it finds one, or if `force` was given, the downloaded install script is executed for the latest version. The `enable` and `disable` options enable or disable the automatic checks that would normally run daily after a successful commit event.

## git hooks readme

Manages the Githooks README in the current repository.

```shell
$ git hooks readme [add|update]
```

Adds or updates the Githooks README in the `.githooks` folder. If `add` is used, it checks first if there is a README file already. With `update`, the file is always updated, creating it if necessary. This command needs to be run at the root of a repository.

## git hooks ignore

Manages Githooks ignore files in the current repository.

```shell
$ git hooks ignore [pattern...]
$ git hooks ignore [trigger] [pattern...]
```

Adds new file name patterns to the Githooks `.ignore` file, either in the main `.githooks` folder, or in the Git event specific one. Note, that it may be required to surround the individual pattern parameters with single quotes to avoid expanding or splitting them. The `trigger` parameter should be the name of the Git event if given. This command needs to be run at the root of a repository.

## git hooks config

Manages various Githooks configuration.

```shell
$ git hooks config list [--global|--local]
```

Lists the Githooks related settings of the Githooks configuration. Can be either global or local configuration, or both by default.

```shell
$ git hooks config [set|reset|print] disable
```

Disables running any Githooks files in the current repository, when the `set` option is used. The `reset` option clears this setting. The `print` option outputs the current setting. This command needs to be run at the root of a repository.

```shell
$ git hooks config set search-dir <path>
$ git hooks config [reset|print] search-dir
```

Changes the previous search directory setting used during installation. The `set` option changes the value, and the `reset` option clears it. The `print` option outputs the current setting of it.

```shell
$ git hooks config set shared <git-url...>
$ git hooks config [reset|print] shared
```

Updates the list of global shared hook repositories when the `set` option is used, which accepts multiple `<git-url>` arguments, each containing a clone URL of a hook repository. The `reset` option clears this setting. The `print` option outputs the current setting.

```shell
$ git hooks config [accept|deny|reset|print] trusted
```

Accepts changes to all existing and new hooks in the current repository when the trust marker is present and the `set` option is used. The `deny` option marks the repository as it has refused to trust the changes, even if the trust marker is present. The `reset` option clears this setting. The `print` option outputs the current setting. This command needs to be run at the root of a repository.

```shell
$ git hooks config [enable|disable|reset|print] update
```

Enables or disables automatic update checks with the `enable` and `disable` options respectively. The `reset` option clears this setting. The `print` option outputs the current setting.

```shell
$ git hooks config [reset|print] update-time
```

Resets the last Githooks update time with the `reset` option, causing the update check to run next time if it is enabled. Use `git hooks update [enable|disable]` to change that setting. The `print` option outputs the current value of it.

```shell
git hooks config set update-clone-url <git-url>
git hooks config [set|print] update-clone-url
```

Sets or prints the configured githooks clone url used for any update.

```shell
git hooks config set update-clone-branch <branch-name>
git hooks config print update-clone-branch
```

Sets or prints the configured branch of the update clone used for any update.

```shell
git hooks config [enable|disable] fail-on-non-existing-shared-hooks
```

Enable or disable failing hooks with an error when any shared hooks configured in `.shared` are missing, which usually means `git hooks update` has not been called yet.

```shell
git hooks config [yes|no|reset|print] delete-detected-lfs-hooks
```

By default, detected LFS hooks during install are disabled and backed up.
The `yes` option remembers to always delete these hooks.
The `no` option remembers the default behavior.
The decision is reset with `reset` to the default behavior.
The `print` option outputs the current behavior.

## git hooks tools

> Experimental feature

Manages script folders for different tools. The supported `<toolName>` are `download` and `dialog` currently.

```shell
$ git hooks tools register [download|dialog] <scriptFolder>
```

Install the script folder `<scriptFolder>` in the installation directory under `tools/<toolName>`.
This folder need to contain a file called `run` that is either executable, or will be invoked as a shell script.
If `run` is an executable it is called as executable, otherwise it is assumed to be a shell script and run by `sh run "$@"`.

### Download tool

The interface of the tool is as follows.

```shell
$ run <relativeFilePath> <outputFile>
```

The arguments are:

- `<relativeFilePath>` is the file relative to the repository root
- `<outputFile>` file to write the results to (may not exist yet)

### Dialog tool

The interface of the tool is as follows.

```shell
$ run <title> <text> <options> <long-options>
```

The arguments for are:

- `<title>` the title for the user gui dialog
- `<text>` the text for the user gui dialog
- `<short-options>` the button return values, slash-delimited,
  e.g. `Y/n/d`.
  The default button is the first capital character found.
- `<long-options>` the button texts in the gui,
  e.g. `Yes/no/disable`

The script needs to return one of the short-options on `stdout`.
If the exit code is not `0`, the normal prompt on `stdin` is shown as a fallback mechanism.

```shell
$ git hooks tools unregister [download|dialog]
```

Uninstall the script folder in the installation directory under `tools/<toolName>`.

## git hooks version

Prints the version number of the command line tool, that should be the same as the last installed Githooks version.

## git hooks help

Prints the help message and the available subcommands. You can also execute `git hooks <cmd> help` for more information on the individual commands.
