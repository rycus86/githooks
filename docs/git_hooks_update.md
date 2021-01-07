## git hooks update

Performs an update check.

### Synopsis


Executes an update check for a newer Githooks version.

git hooks update [force]
git hooks update [enable|disable]

	If it finds one, or if `force` was given, the downloaded
	install script is executed for the latest version.
	The `enable` and `disable` options enable or disable
	the automatic checks that would normally run daily
	after a successful commit event.

```
git hooks update
```

### Options

```
  -h, --help   help for update
```

### SEE ALSO

* [git hooks](git_hooks.md)	 - Githooks CLI application

###### Auto generated by spf13/cobra on 6-Jan-2021