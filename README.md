# Githooks

A simple Shell script to support per-repository [Git hooks](https://git-scm.com/docs/githooks), checked into the actual repository that uses them.

To make this work, it creates hook templates that are installed into the `.git/hooks` folders automatically on `git init` and `git clone`. When one of them executes, it will try to find matching files in the `.githooks` directory under the project root, and invoke them one-by-one.

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
├── README.md
├── LICENSE
└── ...
```

All hooks to be executed live under the `.githooks` top-level folder, that should be checked into the repository. Inside, we can have directories with the name of the hook (like `commit-msg` and `pre-commit` above), or a file matching the hook name (like `post-checkout` in the example). The filenames in the directory do not matter, but the ones starting with a `.` will be excluded by default. All others are executed in alphabetical order according to the [glob / LC_COLLATE](http://pubs.opengroup.org/onlinepubs/007908775/xsh/glob.html) rules. If a file is executable, it is directly invoked, otherwise it is interpreted with the `sh` shell. All parameters of the hook are passed to each of the scripts.

The supported hooks are listed below. Refer to the [Git documentation](https://git-scm.com/docs/githooks) for information on what they do and what parameters they receive.

- `applypatch-msg`
- `pre-applypatch`
- `post-applypatch`
- `pre-commit`
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
- `push-to-checkout`
- `pre-auto-gc`
- `post-rewrite`
- `sendemail-validate`

The `.ignore` files allow excluding files from being treated as a hook script. They allow *glob* filename patterns, empty lines and comments, where the line starts with a `#` character. In the above example, one of the `.ignore` files should contain `*.md` to exclude the `pre-commit/docs.md` Markdown file. The `.githooks/.ignore` file applies to each of the hook directories, and should still define filename patterns, `*.txt` instead of `**/*.txt` for example. If there is a `.ignore` file both in the hook type folder and in `.githooks`, the files whose filename matches any pattern from either of those two files will be excluded. Finally, all hook execution can be bypassed with a non-empty value in the `$GITHOOKS_DISABLE` environment variable.

## Installation

The commands below fetch and execute the [install.sh](install.sh) script from this repository. It will:

1. Find out where the Git templates directory is
    1. From the `$GIT_TEMPLATE_DIR` environment variable
    2. With the `git config --get init.templateDir` command
    3. Checking the default `/usr/share/git-core/templates` folder
    4. Search on the filesystem for matching directories
    5. Offer to set up a new one, and make it `init.templateDir`
2. Set up the hook templates for the supported hooks - the templates are basically a copy of the `base-template.sh` file content
3. Offer to find existing Git repositories on the filesystem, and install the hooks into them

To install the templates, just exectue the command below, and follow the instructions in the terminal.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)"
```

If you want, you can try out what the script would do first, without changing anything.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --dry-run
```

And if you trust GitHub URLs more, use the command below that skips the redirect from `r.viktoradam.net`.

```shell
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/rycus86/githooks/master/install.sh)" -- --dry-run
```

## Acknowledgements

These two projects gave some ideas and inspiration, you should check them out:

- [git-hooks/git-hooks](https://github.com/git-hooks/git-hooks) - written in Go
- [icefox/git-hooks](https://github.com/icefox/git-hooks) - written in Bash

## License

MIT
