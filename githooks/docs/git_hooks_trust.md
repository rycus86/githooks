## git hooks trust

Manages settings related to trusted repositories.

### Synopsis


Sets up, or reverts the trusted setting for the local repository.

When called without arguments, it marks the local repository as trusted.

The `revoke` argument resets the already accepted trust setting,
and the `delete` argument also deletes the trusted marker.

The `forget` option unsets the trust setting, asking for accepting
it again next time, if the repository is marked as trusted.

```
git hooks trust
```

### Options

```
  -h, --help   help for trust
```

### SEE ALSO

* [git hooks](git_hooks.md)	 - Githooks CLI application
* [git hooks trust delete](git_hooks_trust_delete.md)	 - Delete trust settings.
* [git hooks trust forget](git_hooks_trust_forget.md)	 - Forget trust settings.
* [git hooks trust revoke](git_hooks_trust_revoke.md)	 - Revoke trust settings.

###### Auto generated by spf13/cobra on 5-Jan-2021