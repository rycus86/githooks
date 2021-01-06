package trust

import (
	"path"
	ccm "rycus86/githooks/cmd/common"
	"rycus86/githooks/cmd/ignore"
	"rycus86/githooks/cmd/list"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"

	"github.com/spf13/cobra"
)

func getAllHooks(
	log cm.ILogContext,
	hookNames []string,
	gitDir string,
	repoHooksDir string,
	shared hooks.SharedRepos,
	state *list.ListHookState) (allHooks []hooks.Hook) {

	allHooks = make([]hooks.Hook, 0, 10+2*shared.GetCount()) // nolint: gomnd

	for _, hookName := range hookNames {

		// List replaced hooks (normally only one)
		replacedHooks := list.GetAllHooksIn(
			log, path.Join(gitDir, "hooks"), hookName,
			hooks.NamespaceReplacedHook, state, false, true)
		allHooks = append(allHooks, replacedHooks...)

		// List repository hooks
		repoHooks := list.GetAllHooksIn(log, repoHooksDir, hookName,
			hooks.NamespaceRepositoryHook, state, false, false)
		allHooks = append(allHooks, repoHooks...)

		// List all shared hooks
		sharedCount := 0
		for idx, sharedRepos := range shared {
			coll, count := list.GetAllHooksInShared(log, hookName, state, sharedRepos, hooks.SharedHookType(idx))
			sharedCount += count

			for i := range coll {
				allHooks = append(allHooks, coll[i].Hooks...)
			}
		}
	}

	return
}

func apply(log cm.ILogContext, hook *hooks.Hook, checksums *hooks.ChecksumStore, reset bool) {

	sha1, err := cm.GetSHA1HashFile(hook.Path)
	log.AssertNoErrorPanicF(err, "Could not compute SHA1 hash for hook '%s'.", hook.Path)

	if reset {

		removed, err := checksums.SyncChecksumRemove(sha1)
		log.AssertNoErrorPanicF(err, "Could not sync checksum for hook '%s'.", hook.Path)

		if removed != 0 {
			log.InfoF("Removed trust checksum for hook '%s'.", hook.NamespacePath)
		} else {
			log.InfoF("No trust checksum for hook '%s'.", hook.NamespacePath)
		}

	} else {

		err = checksums.SyncChecksumAdd(
			hooks.ChecksumResult{
				SHA1:          sha1,
				Path:          hook.Path,
				NamespacePath: hook.NamespacePath})

		log.AssertNoErrorPanicF(err, "Could not sync checksum for hook '%s'.", hook.Path)

		log.InfoF("Set trust checksum for hook '%s'.", hook.NamespacePath)
	}
}

func runTrustPatterns(ctx *ccm.CmdContext, reset bool, all bool, patterns *hooks.HookPatterns) {
	repoDir, gitDir := ccm.AssertRepoRoot(ctx)

	repoHooksDir := hooks.GetGithooksDir(repoDir)
	hookNames := hooks.ManagedHookNames

	state, shared := list.PrepareListHookState(ctx, repoDir, repoHooksDir, gitDir, hookNames)

	allHooks := getAllHooks(ctx.Log, hookNames, gitDir, repoHooksDir, shared, state)

	countMatches := 0

	for i := range allHooks {
		hook := &allHooks[i]

		if all || patterns.Matches(hook.NamespacePath) {
			countMatches += 1
			apply(ctx.Log, hook, state.Checksums, reset)
		}
	}
}

func NewTrustHooksCmd(ctx *ccm.CmdContext) *cobra.Command {

	reset := false
	all := false
	patterns := hooks.HookPatterns{}

	trustHooks := &cobra.Command{
		Use:   "hooks [flags]",
		Short: "Trust all hooks which match the glob patterns or namespace paths.",
		Long: `Trust all hooks which match the glob patterns or namespace paths given
by '--patterns' or '--paths'.` + "\n\n" +
			ignore.SeeHookListHelpText + "\n\n" +
			ignore.NamespaceHelpText,

		PreRun: func(cmd *cobra.Command, args []string) {
			ccm.PanicIfAnyArgs(ctx.Log)(cmd, args)

			count := len(patterns.NamespacePaths) + len(patterns.Patterns)
			if all {
				count += 1
			}

			ctx.Log.PanicIfF(count == 0, "You need to provide at least one pattern or namespace path.")
		},

		Run: func(cmd *cobra.Command, args []string) {
			runTrustPatterns(ctx, reset, all, &patterns)
		},
	}

	trustHooks.Flags().StringSliceVar(&patterns.Patterns, "patterns", nil,
		"Specified glob patterns matching hook namespace paths.")

	trustHooks.Flags().StringSliceVar(&patterns.NamespacePaths, "paths", nil,
		"Specified namespace paths matching hook namespace paths.")

	trustHooks.Flags().BoolVar(&all, "all", false,
		`If the action applies to all found hooks.
(ignoring '--patterns', '--paths')`)

	trustHooks.Flags().BoolVar(&reset, "reset", false,
		"If the matched hooks are set 'untrusted'.")

	return ccm.SetCommandDefaults(ctx.Log, trustHooks)
}
