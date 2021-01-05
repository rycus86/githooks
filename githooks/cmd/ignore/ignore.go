package ignore

import (
	"os"
	"path"
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/spf13/cobra"
)

type ignoreActionOptions struct {
	UseRepository bool   // Use repositories ignore file.
	HookName      string // Use the subfolder 'HookName''s ignore file.
}

type ignoreShowOptions struct {
	User         bool
	Repository   bool
	OnlyExisting bool
}

func ignoreLoadIgnoreFile(
	ctx *ccm.CmdContext,
	ignAct *ignoreActionOptions,
	repoRoot string,
	gitDir string) (file string, patterns hooks.HookIgnorePatterns) {

	if ignAct.UseRepository {

		ctx.Log.PanicIfF(
			strs.IsNotEmpty(ignAct.HookName) &&
				!strs.Includes(hooks.ManagedHookNames, ignAct.HookName),
			"Given hook name '%s' is not any of the hook names:\n%s", ignAct.HookName,
			ccm.GetFormattedHookList(""))

		file = hooks.GetHookIngoreFileHooksDir(hooks.GetGithooksDir(repoRoot), ignAct.HookName)
	} else {
		file = hooks.GetHookIgnoreFileGitDir(gitDir)
	}

	var err error

	if cm.IsFile(file) {
		patterns, err = hooks.LoadIgnorePatterns(file)
		ctx.Log.AssertNoErrorPanicF(err, "Could not ignore file '%s'.", file)
	}

	return
}

func runIgnoreAddPattern(ctx *ccm.CmdContext, ignAct *ignoreActionOptions, remove bool, patterns []string) {

	repoRoot, gitDir := ccm.AssertRepoRoot(ctx)
	file, ps := ignoreLoadIgnoreFile(ctx, ignAct, repoRoot, gitDir)

	var text string

	if remove {
		if ps.IsEmpty() {
			ctx.Log.WarnF("Ignore file '%s' is empty or does not exist.\nNothing to remove!", file)

			return
		}

		removed := ps.RemovePatterns(patterns...)
		text = strs.Fmt("Removed '%v/%v' pattern(s) from", removed, len(patterns))

	} else {
		for _, p := range patterns {
			if valid := hooks.IsIgnorePatternValid(p); !valid {
				ctx.Log.PanicF("Pattern '%s' is not valid.", p)
			}
		}

		added := ps.AddPatternsUnique(patterns...)
		text = strs.Fmt("Added '%v' pattern(s) to", added)
	}

	err := os.MkdirAll(path.Dir(file), cm.DefaultFileModeDirectory)
	ctx.Log.AssertNoErrorPanicF(err, "Could not make directories for '%s'.", file)

	err = hooks.StoreIgnorePatterns(ps, file)
	ctx.Log.AssertNoErrorPanicF(err, "Could not store ignore file '%s'.", file)

	ctx.Log.InfoF("%s file '%s'.", text, file)
}

func runIgnoreAddPath(ctx *ccm.CmdContext, ignAct *ignoreActionOptions, remove bool, namespacePaths []string) {
	repoRoot, gitDir := ccm.AssertRepoRoot(ctx)
	file, ps := ignoreLoadIgnoreFile(ctx, ignAct, repoRoot, gitDir)

	var text string

	if remove {
		if ps.IsEmpty() {
			ctx.Log.WarnF("Ignore file '%s' is empty or does not exist.\nNothing to remove!", file)

			return
		}

		removed := ps.RemoveNamespacePaths(namespacePaths...)
		text = strs.Fmt("Removed '%v/%v' namespace path(s) from", removed, len(namespacePaths))

	} else {
		added := ps.AddNamespacePathsUnique(namespacePaths...)
		text = strs.Fmt("Added '%v'  namespace path(s) to", added)
	}

	err := os.MkdirAll(path.Dir(file), cm.DefaultFileModeDirectory)
	ctx.Log.AssertNoErrorPanicF(err, "Could not make directories for '%s'.", file)

	err = hooks.StoreIgnorePatterns(ps, file)
	ctx.Log.AssertNoErrorPanicF(err, "Could not store ignore file '%s'.", file)

	ctx.Log.InfoF("%s file '%s'.", text, file)
}

func runIgnoreShow(ctx *ccm.CmdContext, ignShow *ignoreShowOptions) {

	repoRoot, gitDir := ccm.AssertRepoRoot(ctx)
	var sb strings.Builder
	count := 0

	print := func(file string, catergory string) {
		exists := cm.IsFile(file)
		if !ignShow.OnlyExisting || exists {

			_, err := strs.FmtW(
				&sb, " %s '%s' : exists: '%v', type: '%s'\n",
				ccm.ListItemLiteral, file, exists, catergory)
			cm.AssertNoErrorPanic(err, "Could not format ignore files.")

			count += 1
		}
	}

	if ignShow.User {
		print(hooks.GetHookIgnoreFileGitDir(gitDir), "user:local")
	}

	if ignShow.Repository {
		for _, file := range hooks.GetHookIgnoreFilesHooksDir(
			hooks.GetGithooksDir(repoRoot),
			hooks.ManagedHookNames) {

			print(file, "repo")
		}
	}

	ctx.Log.InfoF("Ignore Files [%v]:\n%s", count, sb.String())
}

func addIgnoreOpts(c *cobra.Command, actOpts *ignoreActionOptions) *cobra.Command {
	c.Flags().BoolVar(&actOpts.UseRepository,
		"repository", false,
		`The action affects the repository's main ignore list.`)

	c.Flags().StringVar(&actOpts.HookName,
		"hook-name", "",
		`The action affects the repository's ignore list
in the subfolder '<hook-name>'. (only together with '--repository' flag.)`)

	return c
}

const SeeHookListHelpText = `To see the namespace paths of all hooks in the active repository,
see '<ns-path>' in the output of 'git hooks list'.`

const NamespaceHelpText = `The namespaced path of a hook file consists of
'<namespacePath>' ≔ '<namespace>/<relPath>', where '<relPath>' is the
relative path of the hook with respect to a base directory
'<hooksDir>'.
Note that a namespace path '<namespacePath>' always contains
forward slashes as path separators (on any platform).

The following values are set for '<namespace>' and '<hooksDir>'
in the following three cases:

For local repository hooks in '<repo>/.githooks':

- '<hooksDir>'  ≔ '<repo>/.githooks'
- '<namespace>' ≔ The first white-space trimmed line in the
                   file '<hooksDir>/.namespace' or empty.

For shared repository hooks in '<sharedRepo>' with url '<url>':

- '<hooksDir>'  ≔ '<sharedRepo>'
- '<namespace>' ≔ The first white-space trimmed line in the
                    file '<hooksDir>/.namespace' or the first 10 digits
					of the SHA1 hash of '<url>'.

For previous replace hooks in '<repo>/.git/hooks/<hookName>.replaced.githook':

- '<hooksDir>'  ≔ '<repo>/.git/hooks'
- '<namespace>' ≔ 'hooks'`

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	var ignoreActionOpts = ignoreActionOptions{}
	var ignoreShowOpts = ignoreShowOptions{}

	const userIgnoreListHelpText = `By default the modifications affect only the user ignore list.
To see the path of the user ignore list,
see the output of 'git hooks ignore show --user'.
To use the repository's ignore list use '--repository'
with optional '--hook-name'.`

	ignoreCmd := &cobra.Command{
		Use:   "ignore",
		Short: "Ignores or activates hook in the current repository.",
		Long: `Ignores (or activates) an activated (or ignored)
hook in the current repository.`,
		Run: ccm.PanicWrongArgs(ctx.Log)}

	ignoreAddPatternCmd := &cobra.Command{
		Use:   "add-pattern [flags] [<pattern>]...",
		Short: "Adds a pattern to the ignore list.",
		Long: `Adds a pattern to the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The glob pattern '<pattern>' will match the namespaced path
'<namespacePath>' of a hook.
The glob pattern syntax supports the 'globstar' (double star) syntax
in addition to the syntax in 'https://golang.org/pkg/path/filepath/#Match'.` + "\n\n" +
			NamespaceHelpText,
		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),
		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPattern(ctx, &ignoreActionOpts, false, args)
		}}

	ignoreRemovePatternCmd := &cobra.Command{
		Use:   "remove-pattern [flags] [<pattern>]...",
		Short: "Removes a pattern from the ignore list.",
		Long: `Remove a pattern from the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The glob pattern '<pattern>' needs to exactly match the entry in the user ignore list.

See 'git hooks ignore add-pattern --help' for more information
about the pattern syntax and namespace paths.`,
		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),
		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPattern(ctx, &ignoreActionOpts, true, args)
		}}

	ignoreAddPathCmd := &cobra.Command{
		Use:   "add-path [flags] [<ns-path>]...",
		Short: "Adds a namespaced path to the ignore list.",
		Long: `Adds a namespaced path to the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The '<ns-path>' is the namespaced path '<namespacePath>' of a hook.` + "\n\n" +
			NamespaceHelpText,
		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),
		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPath(ctx, &ignoreActionOpts, false, args)
		}}

	ignoreRemovePathCmd := &cobra.Command{
		Use:   "remove-path [flags] [<ns-path>]...",
		Short: "Removes a namespaced path from the ignore list.",
		Long: `Removes a namespaced path from the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The '<ns-path>' is the namespaced path '<namespacePath>' of a hook.

See 'git hooks ignore add-path --help' for more information
on namespace paths.`,
		PreRun: ccm.PanicIfNotRangeArgs(ctx.Log, 0, -1),
		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPath(ctx, &ignoreActionOpts, true, args)
		}}

	ignoreShowCmd := &cobra.Command{
		Use:    "show [flags]...",
		Short:  "Shows the paths of the ignore files.",
		Long:   `Shows the paths of the ignore files.`,
		PreRun: ccm.PanicIfAnyArgs(ctx.Log),
		Run: func(c *cobra.Command, args []string) {

			if c.Flags().NFlag() == 0 {
				ignoreShowOpts.Repository = true
				ignoreShowOpts.User = true
			}

			runIgnoreShow(ctx, &ignoreShowOpts)
		}}

	ignoreShowCmd.Flags().BoolVar(&ignoreShowOpts.User,
		"user", false, "Show the path of the local user ignore file.")
	ignoreShowCmd.Flags().BoolVar(&ignoreShowOpts.Repository,
		"repository", false, "Show the paths of possible repository ignore files.")

	ignoreShowCmd.Flags().BoolVar(&ignoreShowOpts.OnlyExisting,
		"only-existing", false, "Show only existing ignore files.")

	addIgnoreOpts(ignoreAddPatternCmd, &ignoreActionOpts)
	addIgnoreOpts(ignoreRemovePatternCmd, &ignoreActionOpts)
	addIgnoreOpts(ignoreAddPathCmd, &ignoreActionOpts)
	addIgnoreOpts(ignoreRemovePathCmd, &ignoreActionOpts)

	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreAddPatternCmd))
	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreRemovePatternCmd))
	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreAddPathCmd))
	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreRemovePathCmd))

	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreShowCmd))

	return ccm.SetCommandDefaults(ctx.Log, ignoreCmd)
}
