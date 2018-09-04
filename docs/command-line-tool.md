# Command line helper

- [disable](#git-hooks-disable)
- [enable](#git-hooks-enable)
- [accept](#git-hooks-accept)
- [trust](#git-hooks-trust)
- [list](#git-hooks-list)
- [shared](#git-hooks-shared)
- [update](#git-hooks-update)
- [readme](#git-hooks-readme)
- [version](#git-hooks-version)
- [help](#git-hooks-help)

The `git hooks <cmd>` command line helper provides a convenience utility to manage Githooks configuration, hook files and other related functionality. The [cli.sh](https://github.com/rycus86/githooks/blob/master/cli.sh) script should be an alias for `git hooks`, which is done automatically by the install script with the `git config --global alias.hooks "!${SCRIPT_DIR}/githooks"` command.

See the list of available subcommands below, or run `git hooks help` locally.

## git hooks disable

Disables a hook in the current repository.

```shell
$ git hooks disable [trigger] [hook-script]
$ git hooks disable [hook-script]
$ git hooks disable [trigger]
$ git hooks disable [-a|--all]
$ git hooks disable [-r|--reset]
```

Disables a hook in the current repository. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to disable, or its relative path, or an absolute path, we will try to find it. The `--all` parameter on its own will disable running any Githooks in the current repository, both existing ones and any future hooks. The `--reset` parameter is used to undo this, and let hooks run again. This command needs to be run at the root of a repository.

## git hooks enable

Enables a previously disabled hook in the current repository.

```shell
$ git hooks enable [trigger] [hook-script]
$ git hooks enable [hook-script]
$ git hooks enable [trigger]
```

Enables a hook or hooks in the current repository. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to enable, or its relative path, or an absolute path, we will try to find it. This command needs to be run at the root of a repository.

## git hooks accept

Accept the pending changes of a new or modified hook.

```shell
$ git hooks accept [trigger] [hook-script]
$ git hooks accept [hook-script]
$ git hooks accept [trigger]
```

Accepts a new hook or changes to an existing hook. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to enable, or its relative path, or an absolute path, we will try to find it. This command needs to be run at the root of a repository.

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

## git hooks version

Prints the version number of the command line tool, that should be the same as the last installed Githooks version.

## git hooks help

Prints the help message and the available subcommands. You can also execute `git hooks <cmd> help` for more information on the individual commands.
