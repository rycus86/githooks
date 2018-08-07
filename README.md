# Githooks

[![Build Status](https://travis-ci.org/rycus86/githooks.svg?branch=master)](https://travis-ci.org/rycus86/githooks)
[![Coverage Status](https://coveralls.io/repos/github/rycus86/githooks/badge.svg?branch=master)](https://coveralls.io/github/rycus86/githooks?branch=master)

A simple Shell script to support per-repository [Git hooks](https://git-scm.com/docs/githooks), checked into the actual repository that uses them.

To make this work, it creates hook templates that are installed into the `.git/hooks` folders automatically on `git init` and `git clone`. When one of them executes, it will try to find matching files in the `.githooks` directory under the project root, and invoke them one-by-one.

> Check out the [blog post](https://blog.viktoradam.net/2018/07/26/githooks-auto-install-hooks/) for the long read!

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
├── README.md
├── LICENSE
└── ...
```

All hooks to be executed live under the `.githooks` top-level folder, that should be checked into the repository. Inside, we can have directories with the name of the hook (like `commit-msg` and `pre-commit` above), or a file matching the hook name (like `post-checkout` in the example). The filenames in the directory do not matter, but the ones starting with a `.` will be excluded by default. All others are executed in alphabetical order according to the [glob / LC_COLLATE](http://pubs.opengroup.org/onlinepubs/007908775/xsh/glob.html) rules. If a file is executable, it is directly invoked, otherwise it is interpreted with the `sh` shell. All parameters of the hook are passed to each of the scripts.

## Supported hooks

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

## Ignoring files

The `.ignore` files allow excluding files from being treated as a hook script. They allow *glob* filename patterns, empty lines and comments, where the line starts with a `#` character. In the above example, one of the `.ignore` files should contain `*.md` to exclude the `pre-commit/docs.md` Markdown file. The `.githooks/.ignore` file applies to each of the hook directories, and should still define filename patterns, `*.txt` instead of `**/*.txt` for example. If there is a `.ignore` file both in the hook type folder and in `.githooks`, the files whose filename matches any pattern from either of those two files will be excluded. Finally, all hook execution can be bypassed with a non-empty value in the `$GITHOOKS_DISABLE` environment variable.

## Shared hook repositories

The hooks are primarily designed to execute programs or scripts in the `.githooks` folder of a single repository. However there are use-cases for common hooks, shared between many repositories with similar requirements and functionality. For example, you could make sure Python dependencies are updated on projects that have a `requirements.txt` file, or an `mvn verify` is executed on `pre-commit` for Maven projects, etc.

For this reason, you can place a `.shared` file inside the `.githooks` repository, which can hold a list of repositories, one per line or separated by comma, which hold common and shared hooks. Alternatively, you can have a comma-separated list of shared repositories set in the `githooks.shared` global Git configuration variable, and the hooks in these repositories will execute for all local projects where the base hooks are installed. Below is an example value for this setting.

```shell
$ git config --global --get githooks.shared
git@github.com:shared/hooks-python.git,git@github.com:shared/hooks-maven.git
```

The install script offers to set these up for you, but you can do it any time by changing the global configuration variable. These repositories will be checked out into the `~/.githooks.shared` folder, and are updated automatically after a `post-merge` event (typically a `git pull`) on any local repositories. The layout of these shared repositories is the same as above, with the exception that the hook folders (or files) can be at the project root as well, to avoid the redundant `.githooks` folder.

## Opt-in hooks

To try and make things a little bit more secure, Githooks checks if any new hooks were added we haven't run before, or if any of the existing ones have changed. When they have, it will prompt for confirmation whether you accept those changes or not, and you can also disable specific hooks to skip running them until you decide otherwise. The accepted checksums are maintained in the `.git/.githooks.checksum` file, per local repository.

There is a caveat worth mentioning: if a terminal *(tty)* can't be allocated, then the default action is to accept the changes or new hooks. Let me know in an issue if you strongly disagree, and you think this is a big enough risk worth having slightly worse UX instead.

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
4. Offer to set up shared hook repositories

To install the templates, just exectue the command below, and follow the instructions in the terminal.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)"
```

If you want, you can try out what the script would do first, without changing anything.

```shell
$ sh -c "$(curl -fsSL https://r.viktoradam.net/githooks)" -- --dry-run
```

And if you trust GitHub URLs more, use the command below that skips the redirect from `r.viktoradam.net`. Also, some corporate proxies are not in favour of my Cloudflare certificates for some reason, so you might have a better chance with GitHub links in this case.

```shell
$ sh -c "$(curl -fsSL https://raw.githubusercontent.com/rycus86/githooks/master/install.sh)"
```

### Required tools

Although most systems will usually have these tools (especially if you're using Git), I should mention that the project assumes the following programs to be available:

- `git`
- `awk`
- `sed`
- `grep`
- `find`

### Updates

You can update the scripts any time by running one of the install commands above. It will simply overwrite the templates with the new ones, and if you opt-in to install into existing local repositories, those will get overwritten too.

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
