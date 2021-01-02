package cmd

import (
	"path"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

// listCmd represents the list command.
var listCmd = &cobra.Command{
	Use:   "list [type]...",
	Short: "Lists the active hooks in the current repository.",
	Long: "Lists the active hooks in the current repository along with their state.\n" +
		"This command needs to be run at the root of a repository.\n\n" +
		"If 'type' is given, then it only lists the hooks for that trigger event.\n" +
		"The supported hooks are:\n\n" +
		strings.Join(strs.Map(hooks.ManagedHookNames, func(s string) string { return " - " + s }), "\n") +
		"\n\n",
	PreRun: panicIfNotRangeArgs(0, 100),
	Run: func(cmd *cobra.Command, args []string) {
		if len(args) == 1 {
			args = strs.MakeUnique(args)
			runList(args, true)
		} else {
			runList(hooks.ManagedHookNames, false)
		}
	}}

func runList(hookNames []string, warnNotFound bool) {
	repoDir, gitDir := assertRepoRoot(&settings)

	repoHooksDir := hooks.GetGithooksDir(repoDir)

	// Load checksum store
	checksums, err := hooks.GetChecksumStorage(settings.GitX, gitDir)
	log.AssertNoErrorF(err, "Errors while loading checksum store.")
	log.DebugF("%s", checksums.Summary())

	// Load ignore patterns
	ignores, err := hooks.GetIgnorePatterns(repoHooksDir, gitDir, hookNames)
	log.AssertNoErrorF(err, "Errors while loading ignore patterns.")
	log.DebugF("Worktree ignore patterns: '%q'.", ignores.Worktree)
	log.DebugF("User ignore patterns: '%q'.", ignores.User)

	// Load all shared hooks
	repoSharedHooks, err := hooks.LoadRepoSharedHooks(settings.InstallDir, repoDir)
	log.AssertNoErrorF(err, "Could not load repository shared hooks.")
	localSharedHooks, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
	log.AssertNoErrorF(err, "Could not load local shared hooks.")
	globalSharedHooks, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
	log.AssertNoErrorF(err, "Could not load global shared hooks.")

	isTrusted, _ := hooks.IsRepoTrusted(settings.GitX, repoDir)

	for _, hookName := range hookNames {

		list := listHooks(
			hookName,
			gitDir,
			repoHooksDir,
			repoSharedHooks,
			localSharedHooks,
			globalSharedHooks,
			&checksums,
			&ignores,
			isTrusted)

		log.Info("Hook event: '%s':\n%s", hookName, list)
	}

}

func listHooks(
	hookName string,
	gitDir string,
	repoHooksDir string,
	repoSharedHooks []hooks.SharedHook,
	localSharedHooks []hooks.SharedHook,
	globalSharedHooks []hooks.SharedHook,
	checksums *hooks.ChecksumStore,
	ignores *hooks.RepoIgnorePatterns,
	isTrustedRepo bool) string {

	return ""
}

//nolint: deadcode, unused
func getAllHooksIn(
	hookName string,
	hooksDir string,
	checksums *hooks.ChecksumStore,
	ignores *hooks.RepoIgnorePatterns,
	isTrustedRepo bool,
	addInternalIgnores bool) []hooks.Hook {

	isTrusted := func(hookPath string) (bool, string) {
		if isTrustedRepo {
			return true, ""
		}

		trusted, sha, e := checksums.IsTrusted(hookPath)
		log.AssertNoErrorPanicF(e, "Could not check trust status '%s'.", hookPath)

		return trusted, sha
	}

	var internalIgnores hooks.HookIgnorePatterns

	if addInternalIgnores {
		var e error
		internalIgnores, e = hooks.GetHookIgnorePatternsWorktree(hooksDir, []string{hookName})
		log.AssertNoErrorPanicF(e, "Could not get worktree ignores in '%s'.", hooksDir)
	}

	isIgnored := func(namespacePath string) bool {
		ignored, _ := ignores.IsIgnored(namespacePath)

		return ignored || internalIgnores.IsIgnored(namespacePath)
	}

	hookNamespace, err := hooks.GetHooksNamespace(hooksDir)
	log.AssertNoErrorPanicF(err, "Could not get hook namespace in '%s'", hooksDir)
	dirOrFile := path.Join(hooksDir, hookName)
	hookNamespace = path.Join(hookNamespace, hookName)

	allHooks, err := hooks.GetAllHooksIn(dirOrFile, hookNamespace, isIgnored, isTrusted)
	log.AssertNoErrorPanicF(err, "Errors while collecting hooks in '%s'.", dirOrFile)

	return allHooks
}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(setCommandDefaults(listCmd))
}
