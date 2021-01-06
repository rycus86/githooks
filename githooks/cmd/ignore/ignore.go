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
	gitDir string) (file string, patterns hooks.HookPatterns) {

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

func runIgnoreAddPattern(
	ctx *ccm.CmdContext, ignAct *ignoreActionOptions,
	remove bool, patterns *hooks.HookPatterns) {

	repoRoot, gitDir := ccm.AssertRepoRoot(ctx)
	file, ps := ignoreLoadIgnoreFile(ctx, ignAct, repoRoot, gitDir)

	var text string

	if remove {
		if ps.IsEmpty() {
			ctx.Log.WarnF("Ignore file '%s' is empty or does not exist.\nNothing to remove!", file)

			return
		}

		removed := ps.Remove(patterns)
		text = strs.Fmt("Removed '%v' of '%v' given entries from",
			removed, patterns.GetCount())

	} else {

		for _, p := range patterns.Patterns {
			if valid := hooks.IsHookPatternValid(p); !valid {
				ctx.Log.PanicF("Pattern '%s' is not valid.", p)
			}
		}

		added := ps.AddUnique(patterns)
		text = strs.Fmt("Added '%v' of given '%v' entries to",
			added, patterns.GetCount())
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
in the subfolder '<hook-name>'.
(only together with '--repository' flag.)`)

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

func addFlags(cmd *cobra.Command, patterns *hooks.HookPatterns) {
	cmd.Flags().StringSliceVar(&patterns.Patterns, "patterns", nil,
		"Specified glob patterns matching hook namespace paths.")

	cmd.Flags().StringSliceVar(&patterns.NamespacePaths, "paths", nil,
		"Specified namespace paths matching hook namespace paths.")
}

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

	patterns := hooks.HookPatterns{}

	ignoreAddPatternCmd := &cobra.Command{
		Use:   "add [flags]",
		Short: "Adds a pattern to the ignore list.",
		Long: `Adds a pattern to the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The glob patterns to add given by '--patterns <pattern>...' will match
the namespaced path '<namespacePath>' of a hook.
The namespace paths to add given by '--paths <ns-path>...' will match the full
namespace path '<namespacePath>' of a hook.

The glob pattern syntax supports the 'globstar' (double star) syntax
in addition to the syntax in 'https://golang.org/pkg/path/filepath/#Match'.` + "\n\n" +
			NamespaceHelpText,

		PreRun: func(cmd *cobra.Command, args []string) {
			ccm.PanicIfAnyArgs(ctx.Log)(cmd, args)
			count := len(patterns.NamespacePaths) + len(patterns.Patterns)
			ctx.Log.PanicIfF(count == 0,
				"You need to provide at least one pattern or namespace path.")
		},

		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPattern(ctx, &ignoreActionOpts, false, &patterns)
		}}

	ignoreRemovePatternCmd := &cobra.Command{
		Use:   "remove [flags]",
		Short: "Removes pattern or namespace paths from the ignore list.",
		Long: `Remove patterns or namespace paths from the ignore list.` + "\n\n" +
			userIgnoreListHelpText + "\n\n" +
			SeeHookListHelpText + "\n\n" +
			`The glob patterns given by '--patterns <pattern>...' or the namespace paths
given by '--paths <ns-path>...' need to exactly match the entry in the user ignore list to
be successfully removed.

See 'git hooks ignore add-pattern --help' for more information
about the pattern syntax and namespace paths.`,

		PreRun: func(cmd *cobra.Command, args []string) {
			ccm.PanicIfAnyArgs(ctx.Log)(cmd, args)
			count := len(patterns.NamespacePaths) + len(patterns.Patterns)
			ctx.Log.PanicIfF(count == 0,
				"You need to provide at least one pattern or namespace path.")
		},
		Run: func(c *cobra.Command, args []string) {
			runIgnoreAddPattern(ctx, &ignoreActionOpts, true, &patterns)
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

	addFlags(ignoreAddPatternCmd, &patterns)
	addIgnoreOpts(ignoreAddPatternCmd, &ignoreActionOpts)
	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreAddPatternCmd))

	addFlags(ignoreRemovePatternCmd, &patterns)
	addIgnoreOpts(ignoreRemovePatternCmd, &ignoreActionOpts)
	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreRemovePatternCmd))

	ignoreCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, ignoreShowCmd))

	return ccm.SetCommandDefaults(ctx.Log, ignoreCmd)
}
