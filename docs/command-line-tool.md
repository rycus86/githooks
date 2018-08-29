# Command line helper

- [disable](#git-hooks-disable)
- [enable](#git-hooks-enable)
- [accept](#git-hooks-accept)
- [list](#git-hooks-list)
- [pull](#git-hooks-pull)
- [update](#git-hooks-update)
- [help](#git-hooks-help)
- [version](#git-hooks-version)

The `git hooks <cmd>` command line helper provides a convenience utility to manage Githooks configuration, hook files and other related functionality. The [cli.sh](https://github.com/rycus86/githooks/blob/master/cli.sh) script should be an alias for `git hooks`, which is done automatically by the install script with the `git config --global alias.hooks "!${SCRIPT_DIR}/githooks"` command.

See the list of available subcommands below, or run `git hooks help` locally.

## git hooks disable

Disables a hook in the current repository.

```shell
$ git hooks disable [trigger] [hook-script]
$ git hooks disable [hook-script]
$ git hooks disable [trigger]
```

Disables a hook in the current repository. The `trigger` parameter should be the name of the Git event if given. The `hook-script` can be the name of the file to disable, or its relative path, or an absolute path, we will try to find it. This command needs to be run at the root of a repository.

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

## git hooks list

Lists the active hooks in the current repository.

```shell
$ git hooks list [type]
```

Lists the active hooks in the current repository along with their state. If `type` is given, then it only lists the hooks for that trigger event. This command needs to be run at the root of a repository.

## git hooks pull

Updates the shared repositories.

```shell
$ git hooks pull
```

Updates the shared repositories found either in the global Git configuration, or in the `.githooks/.shared` file in the local repository.

## git hooks update

Performs an update check.

```shell
$ git hooks update [force]
$ git hooks update [enable|disable]
```

Executes an update check for a newer Githooks version. If it finds one, or if `force` was given, the downloaded install script is executed for the latest version. The `enable` and `disable` options enable or disable the automatic checks that would normally run daily after a successful commit event.

## git hooks help

Prints the help message and the available subcommands. You can also execute `git hooks <cmd> help` for more information on the individual commands.

## git hooks version

Prints the version number of the command line tool, that should be the same as the last installed Githooks version.
