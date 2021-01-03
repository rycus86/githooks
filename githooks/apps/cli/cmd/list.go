package cmd

import (
	"io"
	"path"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/pkg/math"
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
		strings.Join(strs.Map(hooks.ManagedHookNames, func(s string) string { return " • " + s }), "\n") +
		"\nThe value 'ns-path' is the namespaced path which is used for the ignore patterns.",
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
	log.DebugF("HooksDir ignore patterns: '%q'.", ignores.HooksDir)
	log.DebugF("User ignore patterns: '%q'.", ignores.User)

	// Load all shared hooks
	repoSharedHooks, err := hooks.LoadRepoSharedHooks(settings.InstallDir, repoDir)
	log.AssertNoErrorF(err, "Could not load repository shared hooks.")
	localSharedHooks, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.LocalScope)
	log.AssertNoErrorF(err, "Could not load local shared hooks.")
	globalSharedHooks, err := hooks.LoadConfigSharedHooks(settings.InstallDir, settings.GitX, git.GlobalScope)
	log.AssertNoErrorF(err, "Could not load global shared hooks.")

	isTrusted, _ := hooks.IsRepoTrusted(settings.GitX, repoDir)
	isDisabled := hooks.IsGithooksDisabled(settings.GitX, true)

	state := ListHooksState{
		checksums:          &checksums,
		ignores:            &ignores,
		isRepoTrusted:      isTrusted,
		isGithooksDisabled: isDisabled,
		sharedIgnores:      make(IgnoresPerHookDir, 10),
		paddingMax:         60} //nolint: gomnd

	for _, hookName := range hookNames {

		list, count := listHooksForName(
			hookName,
			gitDir,
			repoHooksDir,
			repoSharedHooks,
			localSharedHooks,
			globalSharedHooks,
			&state)

		if count != 0 {
			log.InfoF("Hook Event: '%s':%s\n", hookName, list)
		}
	}

}

type IgnoresPerHookDir = map[string]*hooks.HookIgnorePatterns

type ListHooksState struct {
	checksums *hooks.ChecksumStore
	ignores   *hooks.RepoIgnorePatterns

	isRepoTrusted      bool
	isGithooksDisabled bool

	sharedIgnores IgnoresPerHookDir
	paddingMax    int
}

func listHooksForName(
	hookName string,
	gitDir string,
	repoHooksDir string,
	repoSharedHooks []hooks.SharedHook,
	localSharedHooks []hooks.SharedHook,
	globalSharedHooks []hooks.SharedHook,
	state *ListHooksState) (string, int) {

	var sb strings.Builder

	printHooks := func(hooks []hooks.Hook, title string, category string) {
		if len(hooks) == 0 {
			return
		}

		padding := findPaddingListHooks(hooks, state.paddingMax)
		_, err := strs.FmtW(&sb, "\n  ▶ %s", title)
		cm.AssertNoErrorPanicF(err, "Could not write hook state.")

		for _, hook := range hooks {
			sb.WriteString("\n")
			formatHookState(&sb, hook, category, state.isGithooksDisabled, padding, "    ")
		}
	}

	listShared := func(sharedHooks []hooks.SharedHook, title string, category string) {
		for _, sharedHook := range sharedHooks {
			shHooks := getAllHooksIn(hookName, sharedHook.RepositoryDir, state, true, false)
			// @todo remove this as soon as possible
			shHooks = append(shHooks,
				getAllHooksIn(hookName, hooks.GetGithooksDir(sharedHook.RepositoryDir), state, true, false)...)

			printHooks(shHooks, strs.Fmt(title, sharedHook.OriginalURL), category)
		}
	}

	// List replaced hooks (normally only one)
	replacedHooks := getAllHooksIn(hookName, path.Join(gitDir, "hooks"), state, false, true)
	printHooks(replacedHooks, "Replaced Hooks:", "replaced")

	// List repository hooks
	repoHooks := getAllHooksIn(hookName, repoHooksDir, state, false, false)
	printHooks(repoHooks, "Repository Hooks:", "repo")

	// List all shared hooks
	listShared(repoSharedHooks, "Repository Shared Hooks: url: '%s'", "shared:repo")
	listShared(localSharedHooks, "Local Shared Hooks: url: '%s'", "shared:local")
	listShared(globalSharedHooks, "Global Shared Hooks: url: '%s'", "shared:global")

	return sb.String(),
		len(replacedHooks) +
			len(repoHooks) +
			len(repoSharedHooks) + len(localSharedHooks) + len(globalSharedHooks)
}

func findPaddingListHooks(hooks []hooks.Hook, maxPadding int) int {
	const addChars = 3
	max := 0
	for _, hook := range hooks {
		max = math.MaxInt(len(path.Base(hook.Path))+addChars, max)
	}

	return math.MinInt(max, maxPadding)
}

func getAllHooksIn(
	hookName string,
	hooksDir string,
	state *ListHooksState,
	addInternalIgnores bool,
	isReplacedHook bool) []hooks.Hook {

	isTrusted := func(hookPath string) (bool, string) {
		if state.isRepoTrusted {
			return true, ""
		}

		trusted, sha, e := state.checksums.IsTrusted(hookPath)
		log.AssertNoErrorF(e, "Could not check trust status '%s'.", hookPath)

		return trusted, sha
	}

	// Cache repository ignores
	hookDirIgnores := state.sharedIgnores[hooksDir]
	if hookDirIgnores == nil && addInternalIgnores {
		var e error
		igns, e := hooks.GetHookIgnorePatternsHookDir(hooksDir, []string{hookName})
		log.AssertNoErrorF(e, "Could not get worktree ignores in '%s'.", hooksDir)
		state.sharedIgnores[hooksDir] = &igns
		hookDirIgnores = &igns
	}

	isIgnored := func(namespacePath string) bool {
		ignored, byUser := state.ignores.IsIgnored(namespacePath)

		if isReplacedHook {
			return ignored && byUser // Replaced hooks can only be ignored by the user.
		} else if hookDirIgnores != nil {
			return ignored || hookDirIgnores.IsIgnored(namespacePath)
		}

		return ignored
	}

	hookNamespace, err := hooks.GetHooksNamespace(hooksDir)
	log.AssertNoErrorPanicF(err, "Could not get hook namespace in '%s'", hooksDir)

	var dirOrFile string
	if isReplacedHook {
		dirOrFile = path.Join(hooksDir, hooks.GetHookReplacementFileName(hookName))
		hookNamespace = "" // @todo Introduce namespacing here! use: "hooks"
	} else {
		dirOrFile = path.Join(hooksDir, hookName)
		hookNamespace = path.Join(hookNamespace, hookName)
	}

	allHooks, err := hooks.GetAllHooksIn(dirOrFile, hookNamespace, isIgnored, isTrusted)
	log.AssertNoErrorPanicF(err, "Errors while collecting hooks in '%s'.", dirOrFile)

	return allHooks
}

func formatHookState(
	w io.Writer,
	hook hooks.Hook,
	categeory string,
	isGithooksDisabled bool,
	padding int,
	indent string) {

	hooksFmt := strs.Fmt("%s• %%-%vs : ", indent, padding)
	const stateFmt = " state: ['%s', '%s']"
	const disabledStateFmt = " state: ['disabled']"
	const categeoryFmt = ", type: '%s'"
	const namespaceFmt = ", ns-path: '%s'"

	hookPath := strs.Fmt("'%s'", path.Base(hook.Path))

	if isGithooksDisabled {
		_, err := strs.FmtW(w,
			hooksFmt+disabledStateFmt+categeoryFmt+namespaceFmt,
			hookPath, categeory, hook.NamespacePath)

		cm.AssertNoErrorPanicF(err, "Could not write hook state.")

		return
	}

	active := "active" // nolint: goconst
	trusted := "trusted"

	if !hook.Active {
		active = "ignored"
	}

	if !hook.Trusted {
		trusted = "untrusted"
	}

	_, err := strs.FmtW(w,
		hooksFmt+stateFmt+categeoryFmt+namespaceFmt,
		hookPath, active, trusted, categeory, hook.NamespacePath)

	cm.AssertNoErrorPanicF(err, "Could not write hook state.")
}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(setCommandDefaults(listCmd))
}
