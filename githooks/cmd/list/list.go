package list

import (
	"io"
	"path"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/pkg/math"
	"github.com/spf13/cobra"
)

func runList(ctx *ccm.CmdContext, hookNames []string, warnNotFound bool) {
	repoDir, gitDir := ccm.AssertRepoRoot(ctx)

	repoHooksDir := hooks.GetGithooksDir(repoDir)
	state, shared := PrepareListHookState(ctx, repoDir, repoHooksDir, gitDir, hookNames)

	total := 0
	for _, hookName := range hookNames {

		list, count := listHooksForName(
			ctx.Log,
			hookName,
			gitDir,
			repoHooksDir,
			shared,
			state)

		if count != 0 {
			ctx.Log.InfoF("Hook: '%s' [%v]:%s", hookName, count, list)
		}

		total += count
	}

	pendingShared := filterPendingSharedRepos(shared)
	printPendingShared(ctx, pendingShared)

	ctx.Log.InfoF("Total listed hooks: '%v'.", total)
}

type ignoresPerHooksDir = map[string]*hooks.HookPatterns

// PrepareListHookState prepares all
// state needed to list all hooks in the current repository.
func PrepareListHookState(
	ctx *ccm.CmdContext,
	repoDir string,
	repoHooksDir string,
	gitDir string,
	hookNames []string) (*ListHookState, hooks.SharedRepos) {

	// Load checksum store
	checksums, err := hooks.GetChecksumStorage(ctx.GitX, gitDir)
	ctx.Log.AssertNoErrorF(err, "Errors while loading checksum store.")
	ctx.Log.DebugF("%s", checksums.Summary())

	// Load ignore patterns
	ignores, err := hooks.GetIgnorePatterns(repoHooksDir, gitDir, hookNames)
	ctx.Log.AssertNoErrorF(err, "Errors while loading ignore patterns.")
	ctx.Log.DebugF("HooksDir ignore patterns: '%+v'.", ignores.HooksDir)
	ctx.Log.DebugF("User ignore patterns: '%+v'.", ignores.User)

	// Load all shared hooks
	shared := hooks.NewSharedRepos(8) //nolint: gomnd

	shared[hooks.SharedHookTypeV.Repo], err = hooks.LoadRepoSharedHooks(ctx.InstallDir, repoDir)
	ctx.Log.AssertNoErrorF(err, "Could not load repository shared hooks.")

	shared[hooks.SharedHookTypeV.Local], err = hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.LocalScope)
	ctx.Log.AssertNoErrorF(err, "Could not load local shared hooks.")

	shared[hooks.SharedHookTypeV.Global], err = hooks.LoadConfigSharedHooks(ctx.InstallDir, ctx.GitX, git.GlobalScope)
	ctx.Log.AssertNoErrorF(err, "Could not load global shared hooks.")

	isTrusted, _ := hooks.IsRepoTrusted(ctx.GitX, repoDir)
	isDisabled := hooks.IsGithooksDisabled(ctx.GitX, true)

	return &ListHookState{
			Checksums:          &checksums,
			Ignores:            &ignores,
			isRepoTrusted:      isTrusted,
			isGithooksDisabled: isDisabled,
			sharedIgnores:      make(ignoresPerHooksDir, 10)},
		shared
}

type ListHookState struct {
	Checksums *hooks.ChecksumStore
	Ignores   *hooks.RepoIgnorePatterns

	isRepoTrusted      bool
	isGithooksDisabled bool

	sharedIgnores ignoresPerHooksDir
}

func filterPendingSharedRepos(shared hooks.SharedRepos) (pending hooks.SharedRepos) {

	pending = hooks.NewSharedRepos(0)

	// Filter out pending shared hooks.
	filter := func(shRepos []hooks.SharedRepo) (res []hooks.SharedRepo, pending []hooks.SharedRepo) {
		res = make([]hooks.SharedRepo, 0, len(shRepos))
		for idx := range shRepos {
			sh := &shRepos[idx]

			if cm.IsDirectory(sh.RepositoryDir) {
				res = append(res, *sh)
			} else {
				pending = append(pending, *sh)
			}
		}

		return
	}

	for idx := range shared {
		shared[idx], pending[idx] = filter(shared[idx])
	}

	return
}

func printPendingShared(ctx *ccm.CmdContext, shared hooks.SharedRepos) {

	count := shared.GetCount()
	if count == 0 {
		return
	}

	var sb strings.Builder

	listPending := func(shRepos []hooks.SharedRepo, indent string, category string) {
		for _, sh := range shRepos {
			_, err := strs.FmtW(&sb,
				"\n%s%s '%s' state: ['pending'], type: '%s'", indent, ccm.ListItemLiteral, sh.OriginalURL, category)
			cm.AssertNoErrorPanic(err, "Could not write pending hooks.")
		}
	}

	indent := " "
	tagNames := hooks.GetSharedRepoTagNames()
	for i := range shared {
		idx := hooks.SharedHookType(i)
		listPending(shared[idx], indent, tagNames[idx])
	}

	ctx.Log.InfoF("Pending shared hooks [%v]:%s", count, sb.String())
}

func listHooksForName(
	log cm.ILogContext,
	hookName string,
	gitDir string,
	repoHooksDir string,
	shared hooks.SharedRepos,
	state *ListHookState) (string, int) {

	// List replaced hooks (normally only one)
	replacedHooks := GetAllHooksIn(
		log, path.Join(gitDir, "hooks"), hookName,
		hooks.NamespaceReplacedHook, state, false, true)

	// List repository hooks
	repoHooks := GetAllHooksIn(
		log, repoHooksDir, hookName,
		hooks.NamespaceRepositoryHook, state, false, false)

	// List all shared hooks
	sharedCount := 0
	all := make([]SharedHooks, 0, shared.GetCount())
	for idx, sharedRepos := range shared {
		coll, count := GetAllHooksInShared(log, hookName, state, sharedRepos, hooks.SharedHookType(idx))
		sharedCount += count
		all = append(all, coll...)
	}

	var sb strings.Builder
	paddingMax := 60
	printHooks := func(hooks []hooks.Hook, title string, category string) {
		if len(hooks) == 0 {
			return
		}

		padding := findPaddingListHooks(hooks, paddingMax)
		_, err := strs.FmtW(&sb, "\n %s", title)
		cm.AssertNoErrorPanicF(err, "Could not write hook state.")

		for i := range hooks {
			sb.WriteString("\n")
			formatHookState(&sb, &hooks[i], category, state.isGithooksDisabled, padding, "  ")
		}
	}

	printHooks(replacedHooks, "Replaced:", "replaced")
	printHooks(repoHooks, "Repository:", "repo")

	tagNames := hooks.GetSharedRepoTagNames()
	for i := range all {
		printHooks(
			all[i].Hooks,
			strs.Fmt("Shared '%s':", all[i].Repo.OriginalURL),
			tagNames[all[i].Category])
	}

	return sb.String(), len(replacedHooks) + len(repoHooks) + sharedCount
}

func findPaddingListHooks(hooks []hooks.Hook, maxPadding int) int {
	const addChars = 3
	max := 0
	for i := range hooks {
		max = math.MaxInt(len(path.Base(hooks[i].Path))+addChars, max)
	}

	return math.MinInt(max, maxPadding)
}

type SharedHooks struct {
	Repo     *hooks.SharedRepo
	Category hooks.SharedHookType
	Hooks    []hooks.Hook
}

func GetAllHooksInShared(
	log cm.ILogContext,
	hookName string,
	state *ListHookState,
	sharedRepos []hooks.SharedRepo,
	category hooks.SharedHookType) (coll []SharedHooks, count int) {

	coll = make([]SharedHooks, 0, len(sharedRepos))

	for i := range sharedRepos {
		shRepo := &sharedRepos[i]

		hookNamespace := hooks.GetDefaultHooksNamespaceShared(shRepo)

		allHooks := GetAllHooksIn(log, shRepo.RepositoryDir, hookName, hookNamespace, state, true, false)
		// @todo remove this as soon as possible
		allHooks = append(allHooks,
			GetAllHooksIn(log, hooks.GetGithooksDir(shRepo.RepositoryDir), hookName, hookNamespace, state, true, false)...)

		if len(allHooks) != 0 {
			count += len(allHooks)
			coll = append(coll,
				SharedHooks{
					Hooks:    allHooks,
					Repo:     shRepo,
					Category: category})
		}
	}

	return
}

func GetAllHooksIn(
	log cm.ILogContext,
	hooksDir string,
	hookName string,
	hookNamespace string,
	state *ListHookState,
	addInternalIgnores bool,
	isReplacedHook bool) []hooks.Hook {

	isTrusted := func(hookPath string) (bool, string) {
		if state.isRepoTrusted {
			return true, ""
		}

		trusted, sha, e := state.Checksums.IsTrusted(hookPath)
		log.AssertNoErrorF(e, "Could not check trust status '%s'.", hookPath)

		return trusted, sha
	}

	// Cache repository ignores
	hookDirIgnores := state.sharedIgnores[hooksDir]
	if hookDirIgnores == nil && addInternalIgnores {
		var e error
		igns, e := hooks.GetHookPatternsHooksDir(hooksDir, []string{hookName})
		log.AssertNoErrorF(e, "Could not get worktree ignores in '%s'.", hooksDir)
		state.sharedIgnores[hooksDir] = &igns
		hookDirIgnores = &igns
	}

	isIgnored := func(namespacePath string) bool {
		ignored, byUser := state.Ignores.IsIgnored(namespacePath)

		if isReplacedHook {
			return ignored && byUser // Replaced hooks can only be ignored by the user.
		} else if hookDirIgnores != nil {
			return ignored || hookDirIgnores.Matches(namespacePath)
		}

		return ignored
	}

	// Overwrite namespace/name.
	if isReplacedHook {
		hookName = hooks.GetHookReplacementFileName(hookName)
		cm.DebugAssert(strs.IsNotEmpty(hookNamespace), "Wrong namespace")

	} else {
		ns, err := hooks.GetHooksNamespace(hooksDir)
		log.AssertNoErrorPanicF(err, "Could not get hook namespace in '%s'", hooksDir)

		if strs.IsNotEmpty(ns) {
			hookNamespace = ns
		}
	}

	allHooks, err := hooks.GetAllHooksIn(hooksDir, hookName, hookNamespace, isIgnored, isTrusted, false)
	log.AssertNoErrorPanicF(err, "Errors while collecting hooks in '%s'.", hooksDir)

	return allHooks
}

func formatHookState(
	w io.Writer,
	hook *hooks.Hook,
	categeory string,
	isGithooksDisabled bool,
	padding int,
	indent string) {

	hooksFmt := strs.Fmt("%s%s %%-%vs : ", indent, ccm.ListItemLiteral, padding)
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

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	listCmd := &cobra.Command{
		Use:   "list [type]...",
		Short: "Lists the active hooks in the current repository.",
		Long: "Lists the active hooks in the current repository along with their state.\n" +
			"This command needs to be run at the root of a repository.\n\n" +
			"If 'type' is given, then it only lists the hooks for that trigger event.\n" +
			"The supported hooks are:\n\n" +
			ccm.GetFormattedHookList("") + "\n\n" +
			"The value 'ns-path' is the namespaced path which is used for the ignore patterns.",

		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),

		Run: func(cmd *cobra.Command, args []string) {
			if len(args) != 0 {
				args = strs.MakeUnique(args)

				for _, h := range args {
					ctx.Log.PanicIfF(!strs.Includes(hooks.ManagedHookNames, h),
						"Hook type '%s' is not managed by Githooks.", h)
				}

				runList(ctx, args, true)

			} else {
				runList(ctx, hooks.ManagedHookNames, false)
			}
		}}

	return ccm.SetCommandDefaults(ctx.Log, listCmd)
}
