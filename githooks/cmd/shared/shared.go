package shared

import (
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

type SharedOpts struct {
	Shared bool
	Local  bool
	Global bool
	All    bool
}

func sharedOptsSetAll(opts *SharedOpts) {
	if opts.All {
		opts.Shared = true
		opts.Local = true
		opts.Global = true
	}
}

func addSharedOpts(c *cobra.Command, opts *SharedOpts, withAll bool) *cobra.Command {
	c.Flags().BoolVar(&opts.Shared, "shared", false,
		strs.Fmt("Modify the shared hooks list '%s' (default).", hooks.GetRepoSharedFileRel()))

	c.Flags().BoolVar(&opts.Local, "local", false, "Modify the shared hooks list in the local Git config.")

	c.Flags().BoolVar(&opts.Global, "global", false, "Modify the shared hooks list in the global Git config.")

	if withAll {
		c.Flags().BoolVar(&opts.All, "all", false,
			"Modify all shared hooks lists ('--shared', '--local', '--global').")
	}

	return c
}

func runSharedAdd(ctx *ccm.CmdContext, opts *SharedOpts, remove bool, url string) {

	t1 := "add url to"
	t2 := "Added '%s' to"
	if remove {
		t1 = "remove url from"
		t2 = "Removed '%s' from"
	}

	switch {
	case opts.Shared:
		repoDir, _ := ccm.AssertRepoRoot(ctx)
		modified, err := hooks.ModifyRepoSharedHooks(repoDir, url, remove)
		ctx.Log.AssertNoErrorPanicF(err, "Could not %s shared hooks list '%s'.", t1, hooks.GetRepoSharedFileRel())
		if modified {
			ctx.Log.InfoF(t2+" shared hooks list '%s'.", url, hooks.GetRepoSharedFileRel())
		} else {
			ctx.Log.InfoF("Shared hooks url '%s' in '%s' does not exist.", url, hooks.GetRepoSharedFileRel())
		}

	case opts.Local:
		ccm.AssertRepoRoot(ctx)
		modified, err := hooks.ModifyLocalSharedHooks(ctx.GitX, url, remove)
		ctx.Log.AssertNoErrorPanicF(err, "Could not %s local shared hooks.", t1)
		if modified {
			ctx.Log.InfoF(t2+" local shared hooks.", url)
		} else {
			ctx.Log.InfoF("Local shared hooks url '%s' does not exist.", url)
		}

	case opts.Global:
		modified, err := hooks.ModifyGlobalSharedHooks(ctx.GitX, url, remove)
		ctx.Log.AssertNoErrorPanicF(err, "Could not %s global shared hooks.", t1)
		if modified {
			ctx.Log.InfoF(t2+" global shared hooks.", url)
		} else {
			ctx.Log.InfoF("Global shared hooks url '%s' does not exist.", url)
		}

	}
}

func runSharedClear(ctx *ccm.CmdContext, opts *SharedOpts) {
	sharedOptsSetAll(opts)

	if opts.Shared {
		repoDir, _ := ccm.AssertRepoRoot(ctx)
		err := hooks.ClearRepoSharedHooks(repoDir)
		ctx.Log.AssertNoErrorPanicF(err, "Could not clear shared hook list %s'.", hooks.GetRepoSharedFileRel())
		ctx.Log.InfoF("Cleared shared hook list '%s'.", hooks.GetRepoSharedFileRel())
	}

	if opts.Local {
		if !opts.Shared {
			ccm.AssertRepoRoot(ctx)
		}
		err := hooks.ClearLocalSharedHooks(ctx.GitX)
		ctx.Log.AssertNoErrorPanic(err, "Could not clear local shared hook list.")
		ctx.Log.Info("Cleared local shared hook list.")
	}

	if opts.Global {
		err := hooks.ClearGlobalSharedHooks()
		ctx.Log.AssertNoErrorPanic(err, "Could not clear global shared hook list.")
		ctx.Log.Info("Cleared global shared hook list.")
	}
}

func runSharedPurge(ctx *ccm.CmdContext) {
	err := hooks.PurgeSharedDir(ctx.InstallDir)
	ctx.Log.AssertNoErrorPanic(err, "Could not purge all shared repositories.")
	ctx.Log.Info("Purged all shared repositories.")
}

func runSharedList(ctx *ccm.CmdContext, opts *SharedOpts) {
	sharedOptsSetAll(opts)

	formatLine := func(s *hooks.SharedHook) string {
		state := "invalid"

		if !s.IsCloned {
			if cm.IsDirectory(s.RepositoryDir) {
				state = "active"
			}
		} else {
			if !cm.IsDirectory(s.RepositoryDir) {
				state = "pending"
			} else if s.IsCloneValid() {
				state = "active"
			}
		}

		return strs.Fmt(" %s '%s' : state: '%s'", ccm.ListItemLiteral, s.OriginalURL, state)
	}

	format := func(sharedHooks []hooks.SharedHook) string {
		var lst []string
		if len(sharedHooks) == 0 {
			lst = append(lst, strs.Fmt(" %s None", ccm.ListItemLiteral))
		} else {
			for _, s := range sharedHooks {
				lst = append(lst, formatLine(&s))
			}
		}

		return strings.Join(lst, "\n")
	}

	if opts.Shared {
		repoDir, _ := ccm.AssertRepoRoot(ctx)
		shared, err := hooks.LoadRepoSharedHooks(ctx.InstallDir, repoDir)
		ctx.Log.AssertNoErrorPanicF(err, "Could not load shared hook list '%s'.", hooks.GetRepoSharedFileRel())

		ctx.Log.InfoF("Shared hook repositories in '%s':\n%s",
			hooks.GetRepoSharedFileRel(), format(shared))

	}

	if opts.Local {
		if !opts.Shared {
			ccm.AssertRepoRoot(ctx)
		}

		shared, err := hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.LocalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not load local shared hook list.")

		ctx.Log.InfoF("Local shared hook repositories:\n%s", format(shared))

	}

	if opts.Global {
		shared, err := hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not load local shared hook list.")

		ctx.Log.InfoF("Global shared hook repositories:\n%s", format(shared))
	}

}

func runSharedUpdate(ctx *ccm.CmdContext) {
	repoDir, _, err := ctx.GitX.GetRepoRoot()

	var sharedHooks []hooks.SharedHook
	updated := 0
	count := 0

	if err == nil {

		sharedHooks, e := hooks.LoadRepoSharedHooks(ctx.InstallDir, repoDir)

		ctx.Log.AssertNoErrorF(e, "Could not load shared hooks in '%s'.", hooks.GetRepoSharedFileRel())
		if e == nil {
			count, e = hooks.UpdateSharedHooks(ctx.Log, sharedHooks, hooks.SharedHookEnumV.Repo)
			updated += count
		}
		err = cm.CombineErrors(err, e)

		sharedHooks, e = hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.LocalScope)
		ctx.Log.AssertNoErrorF(e, "Could not load local shared hooks.")
		if e == nil {
			count, e = hooks.UpdateSharedHooks(ctx.Log, sharedHooks, hooks.SharedHookEnumV.Local)
			updated += count
		}
		err = cm.CombineErrors(err, e)

	} else {
		ctx.Log.WarnF("Not inside a bare or non-bare repository.\n" +
			"Updating shared and local shared hooks skipped.")
	}

	sharedHooks, e := hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.GlobalScope)
	ctx.Log.AssertNoErrorF(e, "Could not load global shared hooks.")
	if e == nil {
		count, e = hooks.UpdateSharedHooks(ctx.Log, sharedHooks, hooks.SharedHookEnumV.Global)
		updated += count
	}
	err = cm.CombineErrors(err, e)

	ctx.Log.AssertNoErrorPanicF(err, "There have been errors while updating shared hooks")
	ctx.Log.InfoF("Update '%v' shared repositories.", updated)
}

func runSharedLocation(ctx *ccm.CmdContext, urls []string) {
	for _, url := range urls {
		location := hooks.GetSharedCloneDir(ctx.InstallDir, url)
		_, err := ctx.Log.GetInfoWriter().Write([]byte(location + "\n"))
		ctx.Log.AssertNoErrorF(err, "Could not write output.")
	}
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	var opts = SharedOpts{}

	sharedCmd := &cobra.Command{
		Use:   "shared",
		Short: "Manages the shared hook repositories.",
		Long: strs.Fmt(`Manages the shared hook repositories set either in the '%s'
file locally in the repository or in the local or global
Git configuration 'githooks.shared'.`, hooks.GetRepoSharedFileRel())}

	var sharedOptsMess = strs.Fmt(
		`If '--local|--global' is given, then the 'githooks.shared' local/global
Git configuration is modified, or if the '--shared' option (default) is set, the '%s'
file is modified in the local repository.`, hooks.GetRepoSharedFileRel())

	sharedAddCmd := &cobra.Command{
		Use:   "add [flags] <git-url>",
		Short: `Add shared repositories.`,
		Long: "Adds an item, given as '<git-url>' to the shared repositories list." + "\n" +
			sharedOptsMess,
		PreRun: ccm.PanicIfNotExactArgs(ctx.Log, 1),
		Run: func(c *cobra.Command, args []string) {
			if c.Flags().NFlag() == 0 {
				opts.Shared = true
			}
			runSharedAdd(ctx, &opts, false, args[0])
		}}

	var sharedRemoveCmd = &cobra.Command{
		Use:   "remove [flags] <git-url>",
		Short: `Remove shared repositories.`,
		Long: "Remove an item, given as '<git-url>' from the shared repositories list." + "\n" +
			sharedOptsMess,
		PreRun: ccm.PanicIfNotExactArgs(ctx.Log, 1),
		Run: func(c *cobra.Command, args []string) {
			if c.Flags().NFlag() == 0 {
				opts.Shared = true
			}
			runSharedAdd(ctx, &opts, true, args[0])
		}}

	var sharedClearCmd = &cobra.Command{
		Use:   "clear [flags]",
		Short: `Clear shared repositories.`,
		Long: "Clears every item in the shared repositories list." + "\n" +
			sharedOptsMess + "\n" +
			"The '--all' option clears all three lists.",
		Run: func(c *cobra.Command, args []string) {

			if c.Flags().NFlag() == 0 {
				opts.Shared = true
			}

			runSharedClear(ctx, &opts)
		}}

	var sharedPurgeCmd = &cobra.Command{
		Use:   "purge",
		Short: `Purge shared repositories.`,
		Long:  `Deletes all cloned shared hook repositories locally.`,
		Run: func(c *cobra.Command, args []string) {
			runSharedPurge(ctx)
		}}

	var sharedListCmd = &cobra.Command{
		Use:   "list [flags]",
		Short: `List shared repositories.`,
		Long:  `List the shared, local, global or all (default) shared hooks repositories.`,
		Run: func(c *cobra.Command, args []string) {

			if c.Flags().NFlag() == 0 {
				opts.All = true
			}

			runSharedList(ctx, &opts)
		}}

	var sharedUpdateCmd = &cobra.Command{
		Use:   "update",
		Short: `Update shared repositories.`,
		Long: `Update all the shared repositories, either by
running 'git pull' on existing ones or 'git clone' on new ones.`,
		Aliases: []string{"pull"},
		Run: func(cmd *cobra.Command, args []string) {
			runSharedUpdate(ctx)
		}}

	var sharedLocationCmd = &cobra.Command{
		Use:    "location [URL]...",
		Short:  `Get the clone location of a shared repository URL.`,
		Long:   `Returns the clone location of a shared repository URL.`,
		Hidden: true,
		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),
		Run: func(cmd *cobra.Command, args []string) {
			runSharedLocation(ctx, args)
		}}

	addSharedOpts(sharedAddCmd, &opts, false)
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedAddCmd))

	addSharedOpts(sharedRemoveCmd, &opts, false)
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedRemoveCmd))

	addSharedOpts(sharedClearCmd, &opts, true)
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedClearCmd))

	addSharedOpts(sharedListCmd, &opts, true)
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedListCmd))

	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedPurgeCmd))
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedUpdateCmd))
	sharedCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedLocationCmd))

	return ccm.SetCommandDefaults(ctx.Log, sharedCmd)
}
