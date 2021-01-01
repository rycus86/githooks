package cmd

import (
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

// sharedCmd represents the shared command.
var sharedCmd = &cobra.Command{
	Use:   "shared",
	Short: "Manages the shared hook repositories.",
	Long: strs.Fmt(`Manages the shared hook repositories set either in the '%s'
file locally in the repository or in the local or global
Git configuration 'githooks.shared'.`, hooks.GetRepoSharedFileRel())}

var sharedOptsMess = strs.Fmt(`If '--local|--global' is given, then the 'githooks.shared' local/global Git configuration
is modified, or if the '--shared' option (default) is set, the '%s'
file is modified in the local repository.`, hooks.GetRepoSharedFileRel())

var sharedAddCmd = &cobra.Command{
	Use:   "add [flags] <git-url>",
	Short: `Add shared repositories.`,
	Long: "Adds an item, given as '<git-url>' to the shared repositories list." + "\n" +
		sharedOptsMess,
	PreRun: panicIfNotExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if cmd.Flags().NFlag() == 0 {
			sharedOpts.Shared = true
		}
		runSharedAdd(false, args[0])
	}}

var sharedRemoveCmd = &cobra.Command{
	Use:   "remove [flags] <git-url>",
	Short: `Remove shared repositories.`,
	Long: "Remove an item, given as '<git-url>' from the shared repositories list." + "\n" +
		sharedOptsMess,
	PreRun: panicIfNotExactArgs(1),
	Run: func(cmd *cobra.Command, args []string) {
		if cmd.Flags().NFlag() == 0 {
			sharedOpts.Shared = true
		}
		runSharedAdd(true, args[0])
	}}

var sharedClearCmd = &cobra.Command{
	Use:   "clear [flags]",
	Short: `Clear shared repositories.`,
	Long: "Clears every item in the shared repositories list." + "\n" +
		sharedOptsMess + "\n" +
		"The '--all' option clears all three lists.",
	Run: func(cmd *cobra.Command, args []string) {

		if cmd.Flags().NFlag() == 0 {
			sharedOpts.Shared = true
		}

		runSharedClear()
	}}

var sharedPurgeCmd = &cobra.Command{
	Use:   "purge",
	Short: `Purge shared repositories.`,
	Long:  `Deletes all cloned shared hook repositories locally.`,
	Run: func(cmd *cobra.Command, args []string) {
		runSharedPurge()
	}}

var sharedListCmd = &cobra.Command{
	Use:   "list [flags]",
	Short: `List shared repositories.`,
	Long:  `List the shared, local, global or all (default) shared hooks repositories.`,
	Run: func(cmd *cobra.Command, args []string) {

		if cmd.Flags().NFlag() == 0 {
			sharedOpts.All = true
		}

		runSharedList()
	}}

var sharedUpdateCmd = &cobra.Command{
	Use:   "update",
	Short: `Update shared repositories.`,
	Long: `Update all the shared repositories, either by
running 'git pull' on existing ones or 'git clone' on new ones.`,
	Aliases: []string{"pull"},
	Run: func(cmd *cobra.Command, args []string) {
		runSharedUpdate()
	}}

type SharedOpts struct {
	Shared bool
	Local  bool
	Global bool
	All    bool
}

var sharedOpts = SharedOpts{}

func sharedOptsSetAll(opts *SharedOpts) {
	if opts.All {
		opts.Shared = true
		opts.Local = true
		opts.Global = true
	}
}

func addSharedOpts(cmd *cobra.Command, withAll bool) *cobra.Command {
	cmd.Flags().BoolVar(&sharedOpts.Shared, "shared", false,
		strs.Fmt("Modify the shared hooks list '%s' (default).", hooks.GetRepoSharedFileRel()))

	cmd.Flags().BoolVar(&sharedOpts.Local, "local", false, "Modify the shared hooks list in the local Git config.")

	cmd.Flags().BoolVar(&sharedOpts.Global, "global", false, "Modify the shared hooks list in the global Git config.")

	if withAll {
		cmd.Flags().BoolVar(&sharedOpts.All, "all", false,
			"Modify all shared hooks lists ('--shared', '--local', '--global').")
	}

	return cmd
}

func runSharedAdd(remove bool, url string) {

	t1 := "add url to"
	t2 := "Added '%s' to"
	if remove {
		t1 = "remove url from"
		t2 = "Removed '%s' from"
	}

	switch {
	case sharedOpts.Shared:
		repoDir := assertRepoRoot(&settings)
		modified, err := hooks.ModifyRepoSharedHooks(repoDir, url, remove)
		log.AssertNoErrorPanicF(err, "Could not %s shared hooks list '%s'.", t1, hooks.GetRepoSharedFileRel())
		if modified {
			log.InfoF(t2+" shared hooks list '%s'.", url, hooks.GetRepoSharedFileRel())
		} else {
			log.InfoF("Shared hooks url '%s' in '%s' does not exist.", url, hooks.GetRepoSharedFileRel())
		}

	case sharedOpts.Local:
		assertRepoRoot(&settings)
		modified, err := hooks.ModifyLocalSharedHooks(settings.GitX, url, remove)
		log.AssertNoErrorPanicF(err, "Could not %s local shared hooks.", t1)
		if modified {
			log.InfoF(t2+" local shared hooks.", url)
		} else {
			log.InfoF("Local shared hooks url '%s' does not exist.", url)
		}

	case sharedOpts.Global:
		modified, err := hooks.ModifyGlobalSharedHooks(settings.GitX, url, remove)
		log.AssertNoErrorPanicF(err, "Could not %s global shared hooks.", t1)
		if modified {
			log.InfoF(t2+" global shared hooks.", url)
		} else {
			log.InfoF("Global shared hooks url '%s' does not exist.", url)
		}

	}
}

func runSharedClear() {
	sharedOptsSetAll(&sharedOpts)

	if sharedOpts.Shared {
		repoDir := assertRepoRoot(&settings)
		err := hooks.ClearRepoSharedHooks(repoDir)
		log.AssertNoErrorPanicF(err, "Could not clear shared hook list %s'.", hooks.GetRepoSharedFileRel())
		log.InfoF("Cleared shared hook list '%s'.", hooks.GetRepoSharedFileRel())
	}

	if sharedOpts.Local {
		if !sharedOpts.Shared {
			assertRepoRoot(&settings)
		}
		err := hooks.ClearLocalSharedHooks(settings.GitX)
		log.AssertNoErrorPanic(err, "Could not clear local shared hook list.")
		log.Info("Cleared local shared hook list.")
	}

	if sharedOpts.Global {
		err := hooks.ClearGlobalSharedHooks()
		log.AssertNoErrorPanic(err, "Could not clear global shared hook list.")
		log.Info("Cleared global shared hook list.")
	}
}

func runSharedPurge() {
	err := hooks.PurgeSharedDir(settings.InstallDir)
	log.AssertNoErrorPanic(err, "Could not purge all shared repositories.")
	log.Info("Purged all shared repositories.")
}

func runSharedList() {
	sharedOptsSetAll(&sharedOpts)

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

		return strs.Fmt(" - '%s' (%s)", s.OriginalURL, state)
	}

	format := func(sharedHooks []hooks.SharedHook) string {
		var lst []string
		if len(sharedHooks) == 0 {
			lst = append(lst, " - None")
		} else {
			for _, s := range sharedHooks {
				lst = append(lst, formatLine(&s))
			}
		}

		return strings.Join(lst, "\n")
	}

	if sharedOpts.Shared {
		repoDir := assertRepoRoot(&settings)
		shared, err := hooks.LoadRepoSharedHooks(settings.InstallDir, repoDir)
		log.AssertNoErrorPanicF(err, "Could not load shared hook list '%s'.", hooks.GetRepoSharedFileRel())

		log.InfoF("Shared hook repositories in '%s':\n%s",
			hooks.GetRepoSharedFileRel(), format(shared))

	}

	if sharedOpts.Local {
		if !sharedOpts.Shared {
			assertRepoRoot(&settings)
		}

		shared, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
		log.AssertNoErrorPanicF(err, "Could not load local shared hook list.")

		log.InfoF("Local shared hook repositories:\n%s", format(shared))

	}

	if sharedOpts.Global {
		shared, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
		log.AssertNoErrorPanicF(err, "Could not load local shared hook list.")

		log.InfoF("Global shared hook repositories:\n%s", format(shared))
	}

}

func runSharedUpdate() {
	repoDir, err := settings.GitX.GetRepoRoot()

	var sharedHooks []hooks.SharedHook
	updated := 0

	if err == nil {

		sharedHooks, e := hooks.LoadRepoSharedHooks(settings.InstallDir, repoDir)

		log.AssertNoErrorF(e, "Could not load shared hooks in '%s'.", hooks.GetRepoSharedFileRel())
		if e == nil {
			err = cm.CombineErrors(err, hooks.UpdateSharedHooks(log, sharedHooks, hooks.SharedHookEnumV.Repo))
		} else {
			err = cm.CombineErrors(err, e)
		}
		updated += len(sharedHooks)

		sharedHooks, e = hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
		log.AssertNoErrorF(e, "Could not load local shared hooks.")
		if e == nil {
			err = cm.CombineErrors(err, hooks.UpdateSharedHooks(log, sharedHooks, hooks.SharedHookEnumV.Local))
		} else {
			err = cm.CombineErrors(err, e)
		}
		updated += len(sharedHooks)

	} else {
		log.WarnF("Not inside a bare or non-bare repository.\n" +
			"Updating shared and local shared hooks skipped.")
	}

	sharedHooks, e := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
	log.AssertNoErrorF(e, "Could not load global shared hooks.")
	if e == nil {
		err = cm.CombineErrors(err, hooks.UpdateSharedHooks(log, sharedHooks, hooks.SharedHookEnumV.Global))
	} else {
		err = cm.CombineErrors(err, e)
	}
	updated += len(sharedHooks)

	log.AssertNoErrorPanicF(err, "There have been errors while updating shared hooks")
	log.InfoF("Update '%v' shared repositories.", updated)
}

func init() { // nolint: gochecknoinits

	sharedCmd.AddCommand(addSharedOpts(setCommandDefaults(sharedAddCmd), false))
	sharedCmd.AddCommand(addSharedOpts(setCommandDefaults(sharedRemoveCmd), false))
	sharedCmd.AddCommand(addSharedOpts(setCommandDefaults(sharedClearCmd), true))
	sharedCmd.AddCommand(setCommandDefaults(sharedPurgeCmd))
	sharedCmd.AddCommand(addSharedOpts(setCommandDefaults(sharedListCmd), true))
	sharedCmd.AddCommand(setCommandDefaults(sharedUpdateCmd))

	rootCmd.AddCommand(setCommandDefaults(sharedCmd))
}
