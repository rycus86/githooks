package cmd

import (
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

}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(setCommandDefaults(listCmd))
}
