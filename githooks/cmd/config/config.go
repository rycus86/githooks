package config

import (
	ccm "rycus86/githooks/cmd/common"
	"rycus86/githooks/cmd/disable"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
	"strings"
	"time"

	"github.com/pkg/math"
	"github.com/spf13/cobra"
)

type GitOptions struct {
	Local  bool
	Global bool
}

func wrapToGitScope(log cm.ILogContext, opts *GitOptions) git.ConfigScope {
	switch {
	default:
		fallthrough
	case opts.Local && opts.Global:
		log.PanicF("You cannot use '--local' or '--global' at the same time.")

		return git.LocalScope
	case opts.Local:
		return git.LocalScope
	case opts.Global:
		return git.GlobalScope
	}
}

type SetOptions struct {
	Print bool
	Reset bool

	Unset  bool
	Set    bool
	Values []string
}

func (s *SetOptions) AssertOptions(log cm.ILogContext, optsMap *OptionsMapping, noValues bool, args []string) {

	log.PanicIf(!s.Set && !s.Unset && !s.Reset && !s.Print, "You need to specify an option.")

	log.PanicIfF(s.Print && (s.Reset || s.Unset || s.Set || len(args) != 0),
		"You cannot use '--%s' with any other options\n"+
			"or arguments at the same time.", optsMap.Print)

	log.PanicIfF(s.Reset && (s.Unset || s.Print || s.Set || len(args) != 0),
		"You cannot use '--%s' with any other options\n"+
			"or arguments at the same time.", optsMap.Reset)

	log.PanicIfF(s.Unset && (s.Print || s.Reset || s.Set || len(args) != 0),
		"You cannot use '--%s' with any other options\n"+
			"or arguments at the same time.", optsMap.Unset)

	log.PanicIfF(s.Set && (s.Print || s.Reset || s.Unset || (!noValues && len(args) == 0)),
		"You cannot use '--%s' with any other options\n"+
			"and you need to specify values.", optsMap.Set)

	if s.Set {
		for i := range args {
			log.PanicIfF(strs.IsEmpty(args[i]), "Argument '%v' may not be empty.", args[i])
		}

		s.Values = args
	}
}

type OptionsMapping struct {
	Print     string
	PrintDesc string
	Set       string
	SetDesc   string
	Unset     string
	UnsetDesc string
	Reset     string
	ResetDesc string
}

func createOptionMap(hasSet bool, hasUnset bool, hasReset bool) OptionsMapping {
	opts := OptionsMapping{
		Print:     "print",
		PrintDesc: "Print the setting."}

	if hasSet {
		opts.Set = "set"
		opts.SetDesc = "Set the setting."
	}

	if hasUnset {
		opts.Unset = "unset"
		opts.UnsetDesc = "Unset the setting."
	}

	if hasReset {
		opts.Reset = "reset"
		opts.ResetDesc = "Reset the setting."
	}

	return opts
}

func wrapToEnableDisable(opts *OptionsMapping) {
	opts.Set = "enable"
	opts.Unset = "disable"
}

func configSetOptions(
	cmd *cobra.Command,
	opts *SetOptions,
	optsMap *OptionsMapping,
	log cm.ILogContext,
	nMinArgs int, nMaxArgs int) {

	if strs.IsNotEmpty(optsMap.Print) {
		cmd.Flags().BoolVar(&opts.Print, optsMap.Print, false, optsMap.PrintDesc)
	}
	if strs.IsNotEmpty(optsMap.Set) {
		cmd.Flags().BoolVar(&opts.Set, optsMap.Set, false, optsMap.SetDesc)
	}
	if strs.IsNotEmpty(optsMap.Unset) {
		cmd.Flags().BoolVar(&opts.Unset, optsMap.Unset, false, optsMap.UnsetDesc)
	}
	if strs.IsNotEmpty(optsMap.Reset) {
		cmd.Flags().BoolVar(&opts.Reset, optsMap.Reset, false, optsMap.ResetDesc)
	}

	rangeCheck := ccm.PanicIfNotRangeArgs(log, nMinArgs, nMaxArgs)
	cmd.PreRun = func(cmd *cobra.Command, args []string) {
		opts.AssertOptions(log, optsMap, nMaxArgs == 0, args)
		if opts.Set {
			rangeCheck(cmd, args)
		}
	}
}

func runList(ctx *ccm.CmdContext, gitOpts *GitOptions) {

	print := func(scope git.ConfigScope) string {

		pairs := ctx.GitX.GetConfigRegex("(^githooks|alias.hooks)", scope)

		maxLength := 0
		for i := range pairs {
			maxLength = math.MaxInt(maxLength, len(pairs[i][0])+2) // nolint: gomnd
		}
		keyFmt := strs.Fmt("%%-%vs", maxLength)

		if len(pairs) == 0 {
			return "[0]: none"
		}

		var sb strings.Builder
		_, err := strs.FmtW(&sb, "[%v]:", len(pairs))
		cm.AssertNoErrorPanic(err, "Could not write message.")

		for i := range pairs {
			key := strs.Fmt("'%s'", pairs[i][0])
			_, err = strs.FmtW(&sb, "\n%s "+keyFmt+" : '%s'", ccm.ListItemLiteral, key, pairs[i][1])
			cm.AssertNoErrorPanic(err, "Could not write message.")
		}

		return sb.String()
	}

	if gitOpts.Local {
		ctx.Log.InfoF("Local Githooks configurations %s", print(git.LocalScope))
	}

	if gitOpts.Global {
		ctx.Log.InfoF("Global Githooks configurations %s", print(git.GlobalScope))
	}

}

func runDisable(ctx *ccm.CmdContext, opts *SetOptions) {
	disable.RunDisable(ctx, opts.Reset, opts.Print)
}

func runSearchDir(ctx *ccm.CmdContext, opts *SetOptions) {
	opt := hooks.GitCK_PreviousSearchDir
	switch {
	case opts.Set:
		err := ctx.GitX.SetConfig(opt, opts.Values[0], git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set Git config '%s'.", opt)
		ctx.Log.InfoF("Set previous search directory used during install to\n'%s'.", opts.Values[0])

	case opts.Reset:
		err := ctx.GitX.UnsetConfig(opt, git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not unset Git config '%s'.", opt)
		ctx.Log.Info("Unset previous search directory used during install.")

	case opts.Print:
		conf := ctx.GitX.GetConfig(opt, git.GlobalScope)
		if strs.IsEmpty(conf) {
			ctx.Log.InfoF("Previous search directory is not set.")
		} else {
			ctx.Log.InfoF("Previous search directory is set to\n'%s'.", conf)
		}
	default:
		cm.Panic("Wrong arguments.")
	}
}

func runSharedRepos(ctx *ccm.CmdContext, opts *SetOptions, gitOpts *GitOptions) {
	opt := hooks.GitCK_Shared

	localOrGlobal := "local"
	if gitOpts.Global {
		localOrGlobal = "global"
	}

	switch {
	case opts.Set:
		scope := wrapToGitScope(ctx.Log, gitOpts)
		for i := range opts.Values {
			err := ctx.GitX.AddConfig(opt, opts.Values[i], scope)
			ctx.Log.AssertNoErrorPanicF(err, "Could not add %s shared repository.", localOrGlobal)
		}
		ctx.Log.InfoF("Added '%v' %s shared repositories.", len(opts.Values), localOrGlobal)

	case opts.Reset:
		scope := wrapToGitScope(ctx.Log, gitOpts)
		err := ctx.GitX.UnsetConfig(opt, scope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not unset %s shared repository.", localOrGlobal)
		ctx.Log.InfoF("Removed all %s shared repositories.", localOrGlobal)

	case opts.Print:
		list := func(sh []string) string {
			if len(sh) == 0 {
				return "[0]: none"
			}

			return strs.Fmt("[%v]:\n%s", len(sh),
				strings.Join(strs.Map(sh,
					func(s string) string { return strs.Fmt("%s '%s'", ccm.ListItemLiteral, s) }),
					"\n"))
		}

		if gitOpts.Local {
			shared := ctx.GitX.GetConfigAll(opt, git.LocalScope)
			ctx.Log.InfoF("Local shared repositories %s", list(shared))
		}

		if gitOpts.Global {
			shared := ctx.GitX.GetConfigAll(opt, git.GlobalScope)
			ctx.Log.InfoF("Global shared repositories %s", list(shared))
		}

	default:
		cm.Panic("Wrong arguments.")
	}
}

func runCloneUrl(ctx *ccm.CmdContext, opts *SetOptions) {
	switch {
	case opts.Set:
		err := updates.SetCloneURL(opts.Values[0], "")
		ctx.Log.AssertNoErrorPanic(err, "Could not set Git hooks clone url.")
		ctx.Log.InfoF("Set Githooks clone URL to '%s'.", opts.Values[0])

	case opts.Print:
		url, branch := updates.GetCloneURL()
		if strs.IsNotEmpty(branch) {
			ctx.Log.InfoF("Githooks clone URL is set to '%s' at branch '%s'.", url, branch)
		} else {
			ctx.Log.InfoF("Githooks clone URL is set to '%s' at default branch.", url)
		}
	default:
		cm.Panic("Wrong arguments.")
	}
}

func runCloneBranch(ctx *ccm.CmdContext, opts *SetOptions) {

	switch {
	case opts.Set:
		err := updates.SetCloneBranch(opts.Values[0])
		ctx.Log.AssertNoErrorPanic(err, "Could not set Git hooks clone branch.")
		ctx.Log.InfoF("Set Githooks clone branch to '%s'.", opts.Values[0])

	case opts.Reset:
		err := updates.ResetCloneBranch()
		ctx.Log.AssertNoErrorPanic(err, "Could not unset Git hooks clone branch.")
		ctx.Log.Info("Unset Githooks clone branch. Using default branch.")

	case opts.Print:
		url, branch := updates.GetCloneURL()
		if strs.IsNotEmpty(branch) {
			ctx.Log.InfoF("Githooks clone URL is set to '%s' at branch '%s'.", url, branch)
		} else {
			ctx.Log.InfoF("Githooks clone URL is set to '%s' at default branch.", url)
		}
	default:
		cm.Panic("Wrong arguments.")
	}
}

func runUpdateTime(ctx *ccm.CmdContext, opts *SetOptions) {
	const text = "Githooks update check timestamp"

	switch {
	case opts.Reset:
		err := updates.ResetUpdateCheckTimestamp()
		ctx.Log.AssertNoErrorPanicF(err, "Could not reset %s.", text)
		ctx.Log.InfoF("Reset %s.", text)

	case opts.Print:
		ts, isSet, err := updates.GetUpdateCheckTimestamp()
		ctx.Log.AssertNoErrorPanic(err, "Could not get %s.", text)
		if isSet {
			ctx.Log.InfoF("%s set to '%s'.", ts.Format(time.RFC1123))
		} else {
			ctx.Log.InfoF("%s is not set.\n"+
				"Update checks have never run.", text)
		}
	default:
		cm.Panic("Wrong arguments.")
	}
}

func runTrust(ctx *ccm.CmdContext, opts *SetOptions) {

	switch {
	case opts.Set:
		err := hooks.SetTrustAllSetting(ctx.GitX, true, false)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set trust-all-hooks setting.")
		ctx.Log.InfoF("The current repository trusts all hooks automatically.")

	case opts.Unset:
		err := hooks.SetTrustAllSetting(ctx.GitX, false, false)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set trust-all-hooks  setting.")
		ctx.Log.InfoF("The current repository trusts all hooks automatically.")

	case opts.Reset:
		err := hooks.SetTrustAllSetting(ctx.GitX, false, true)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set trust-all setting.")
		ctx.Log.InfoF("The trust-all-hooks setting is not set in the current repository.")

	case opts.Print:
		enabled, isSet := hooks.GetTrustAllSetting(ctx.GitX)
		switch {
		case !isSet:
			ctx.Log.Info("The trust-all-hooks setting is not set in the current repository.")
		case enabled:
			ctx.Log.Info("The current repository trusts all hooks automatically.")
		default:
			ctx.Log.Info("The current repository does not trust hooks automatically.")
		}

	default:
		cm.Panic("Wrong arguments.")
	}

}

func runUpdate(ctx *ccm.CmdContext, opts *SetOptions) {
	const text = "Automatic Githooks update"

	switch {
	case opts.Set:
		err := updates.SetAutomaticUpdateCheckSettings(true, false)
		ctx.Log.AssertNoErrorPanicF(err, "Could not enable automatic update settings.")
		ctx.Log.InfoF("%s checks are now enabled.", text)

	case opts.Unset:
		err := updates.SetAutomaticUpdateCheckSettings(false, false)
		ctx.Log.AssertNoErrorPanicF(err, "Could not disable automatic update settings.")
		ctx.Log.InfoF("%s checks are now disabled.", text)

	case opts.Reset:
		err := updates.SetAutomaticUpdateCheckSettings(false, true)
		ctx.Log.AssertNoErrorPanicF(err, "Could not reset automatic update settings.")
		ctx.Log.InfoF("%s setting is now unset.", text)

	case opts.Print:
		enabled, _ := updates.GetAutomaticUpdateCheckSettings()
		switch {
		case enabled:
			ctx.Log.InfoF("%s checks are enabled.", text)
		default:
			ctx.Log.InfoF("%s checks are disabled.", text)
		}

	default:
		cm.Panic("Wrong arguments.")
	}
}

func runNonExistingSharedHooks(ctx *ccm.CmdContext, opts *SetOptions, gitOpts *GitOptions) {
	scope := wrapToGitScope(ctx.Log, gitOpts)

	localOrGlobal := "locally"
	if gitOpts.Global {
		localOrGlobal = "globally"
	}

	const text = "on non existing shared hooks"
	switch {
	case opts.Set:
		err := hooks.SetFailOnNonExistingSharedHooks(ctx.GitX, true, false, scope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not enable failing %s %s.", text, localOrGlobal)
		ctx.Log.InfoF("Enabled failing %s %s.", text, localOrGlobal)

	case opts.Unset:
		err := hooks.SetFailOnNonExistingSharedHooks(ctx.GitX, false, false, scope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not disable failing %s %s.", text, localOrGlobal)
		ctx.Log.InfoF("Disabled failing %s %s.", text, localOrGlobal)

	case opts.Reset:
		err := hooks.SetFailOnNonExistingSharedHooks(ctx.GitX, false, true, scope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not reset failing %s %s.", text, localOrGlobal)
		ctx.Log.InfoF("Reset setting for failing %s %s.", text, localOrGlobal)

	case opts.Print:
		enabled, _ := hooks.GetFailOnNonExistingSharedHooks(ctx.GitX, scope)
		if enabled {
			ctx.Log.InfoF("Failing %s is enabled %s.", text, localOrGlobal)
		} else {
			ctx.Log.InfoF("Failing %s is disabled %s.", text, localOrGlobal)
		}

	default:
		cm.Panic("Wrong arguments.")
	}
}

func runDeleteDetectedLFSHooks(ctx *ccm.CmdContext, opts *SetOptions) {
	opt := hooks.GitCK_DeleteDetectedLFSHooksAnswer

	switch {
	case opts.Set:
		err := ctx.GitX.SetConfig(opt, "a", git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set Git config '%s'.", opt)
		ctx.Log.InfoF("Detected LFS hooks will now automatically be deleted during install.")

	case opts.Unset:
		err := ctx.GitX.SetConfig(opt, "n", git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not set Git config '%s'.", opt)
		ctx.Log.Info("Detected LFS hooks will now automatically be deleted during install",
			"but instead backed up.")

	case opts.Reset:
		err := ctx.GitX.UnsetConfig(opt, git.GlobalScope)
		ctx.Log.AssertNoErrorPanicF(err, "Could not unset Git config '%s'.", opt)
		ctx.Log.Info("Decision to delete LFS hooks is reset and now left to the user.")

	case opts.Print:
		conf := ctx.GitX.GetConfig(opt, git.GlobalScope)
		switch {
		case conf == "a":
			ctx.Log.Info("Detected LFS hooks are automatically deleted during install.")
		case conf == "n":
			ctx.Log.Info("Detected LFS hooks are not automatically deleted during install",
				"but instead backed up.")
		default:
			ctx.Log.Info("Deletion of detected LFS hooks is undefined and left to the user.")
		}

	default:
		cm.Panic("Wrong arguments.")
	}
}

func configListCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, gitOpts *GitOptions) {

	listCmd := &cobra.Command{
		Use:   "list [flags]",
		Short: "Lists settings of the Githooks configuration.",
		Long: `Lists the Githooks related settings of the Githooks configuration.
Can be either global or local configuration, or both by default.`,
		PreRun: ccm.PanicIfAnyArgs(ctx.Log),
		Run: func(cmd *cobra.Command, args []string) {

			if !gitOpts.Local && !gitOpts.Global {
				_, _, err := ctx.GitX.GetRepoRoot()
				gitOpts.Local = err == nil
				gitOpts.Global = true

			} else if gitOpts.Local {
				ccm.AssertRepoRoot(ctx)
			}

			runList(ctx, gitOpts)
		}}

	listCmd.Flags().BoolVar(&gitOpts.Local, "local", false, "Use the local Git configuration.")
	listCmd.Flags().BoolVar(&gitOpts.Global, "global", false, "Use the global Git configuration.")
	configCmd.AddCommand(listCmd)
}

func configDisableCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions, gitOpts *GitOptions) {

	disableCmd := &cobra.Command{
		Use:   "disable [flags]",
		Short: "Disables Githooks in the current repository.",
		Long: `Disables Githooks in the current repository.
LFS hooks and replaced previous hooks are still executed.
This command needs to be run at the root of a repository.`,
		Run: func(cmd *cobra.Command, args []string) {
			runDisable(ctx, setOpts)
		}}

	optsPSR := createOptionMap(true, false, true)

	configSetOptions(disableCmd, setOpts, &optsPSR, ctx.Log, 0, 0)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, disableCmd))
}

func configSearchDirCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	searchDirCmd := &cobra.Command{
		Use:   "search-dir [flags]",
		Short: "Changes the search directory used during installation.",
		Long: `Changes the previous search directory setting
used during installation.`,
		Run: func(cmd *cobra.Command, args []string) {
			runSearchDir(ctx, setOpts)
		}}

	optsPSR := createOptionMap(true, false, true)

	configSetOptions(searchDirCmd, setOpts, &optsPSR, ctx.Log, 1, 1)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, searchDirCmd))
}

func configCloneUrlCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	cloneUrlCmd := &cobra.Command{
		Use:   "clone-url [flags]",
		Short: "Changes the Githooks clone url used for any update.",
		Long:  `Changes the Githooks clone url used for any update.`,
		Run: func(cmd *cobra.Command, args []string) {
			runCloneUrl(ctx, setOpts)
		}}

	optsPrintSet := createOptionMap(true, false, false)

	configSetOptions(cloneUrlCmd, setOpts, &optsPrintSet, ctx.Log, 1, 1)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, cloneUrlCmd))
}

func configCloneBranchCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	cloneBranchCmd := &cobra.Command{
		Use:   "clone-branch [flags]",
		Short: "Changes the Githooks clone url used for any update.",
		Long:  `Changes the Githooks clone url used for any update.`,
		Run: func(cmd *cobra.Command, args []string) {
			runCloneBranch(ctx, setOpts)
		}}

	optsPSR := createOptionMap(true, false, true)

	configSetOptions(cloneBranchCmd, setOpts, &optsPSR, ctx.Log, 1, 1)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, cloneBranchCmd))
}

func configTrustCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	trustCmd := &cobra.Command{
		Use:   "trusted [flags]",
		Short: "Change trust settings in the current repository.",
		Long: `Change the trust setting in the current repository.

This command needs to be run at the root of a repository.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(ctx, setOpts)
		}}

	optsPSUR := createOptionMap(true, true, true)
	optsPSUR.Set = "accept"
	optsPSUR.SetDesc = "Accepts changes to all existing and new hooks\n" +
		"in the current repository when the trust marker\nis present."
	optsPSUR.Unset = "deny"
	optsPSUR.UnsetDesc = "Marks the repository as it has refused to\n" +
		"trust the changes, even if the trust marker is present."
	optsPSUR.ResetDesc = "Clears the trust setting."

	configSetOptions(trustCmd, setOpts, &optsPSUR, ctx.Log, 0, 0)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, trustCmd))
}

func configUpdateCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	updateCmd := &cobra.Command{
		Use:   "update [flags]",
		Short: "Change Githooks update settings.",
		Long:  `Enable or disable automatic Githooks updates.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUpdate(ctx, setOpts)
		}}

	optsPSUR := createOptionMap(true, true, true)
	wrapToEnableDisable(&optsPSUR)
	optsPSUR.SetDesc = "Enables automatic update checks for Githooks."
	optsPSUR.UnsetDesc = "Disables automatic update checks for Githooks."

	configSetOptions(updateCmd, setOpts, &optsPSUR, ctx.Log, 0, 0)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, updateCmd))

}

func configUpdateTimeCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions) {

	updateTimeCmd := &cobra.Command{
		Use:   "update-time [flags]",
		Short: "Changes the Githooks update time.",
		Long: `Changes the Githooks update time used to check for updates.

Resets the last Githooks update time with the '--reset' option,
causing the update check to run next time if it is enabled.
Use 'git hooks update [--enable|--disable]' to change that setting.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUpdateTime(ctx, setOpts)
		}}

	optsPR := createOptionMap(false, false, true)

	configSetOptions(updateTimeCmd, setOpts, &optsPR, ctx.Log, 0, 0)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, updateTimeCmd))
}

func configSharedCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions, gitOpts *GitOptions) {

	sharedCmd := &cobra.Command{
		Use:   "shared [flags] [<git-url>...]",
		Short: "Updates the list of local or global shared hook repositories.",
		Long: `Updates the list of local or global shared hook repositories.

The '--add' option accepts multiple '<git-url>' arguments,
each containing a clone URL of a shared hook repository which gets added.`,
		Run: func(cmd *cobra.Command, args []string) {

			if !gitOpts.Local && !gitOpts.Global {
				_, _, err := ctx.GitX.GetRepoRoot()
				gitOpts.Global = true
				gitOpts.Local = setOpts.Print && err == nil
			} else if gitOpts.Local {
				ccm.AssertRepoRoot(ctx)
			}

			runSharedRepos(ctx, setOpts, gitOpts)
		}}

	optsPSR := createOptionMap(true, false, true)
	optsPSR.Set = "add"
	optsPSR.SetDesc = "Adds given shared hook repositories '<git-url>'s."
	sharedCmd.Flags().BoolVar(&gitOpts.Local, "local", false, "Use the local Git configuration.")
	sharedCmd.Flags().BoolVar(&gitOpts.Global, "global", false, "Use the global Git configuration (default).")

	configSetOptions(sharedCmd, setOpts, &optsPSR, ctx.Log, 1, -1)
	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, sharedCmd))
}

func configNonExistSharedRepo(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions, gitOpts *GitOptions) {

	nonExistSharedCmd := &cobra.Command{
		Use:   "fail-on-non-existing-shared-hooks [flags]",
		Short: "Updates the list of local or global shared hook repositories.",
		Long: `Enable or disable failing hooks with an error when any
shared hooks are missing. This usually means 'git hooks shared update'
has not been called yet.`,
		Run: func(cmd *cobra.Command, args []string) {
			if !gitOpts.Local && !gitOpts.Global {
				gitOpts.Local = true
			}

			if gitOpts.Local {
				ccm.AssertRepoRoot(ctx)
			}

			runNonExistingSharedHooks(ctx, setOpts, gitOpts)
		}}

	optsPSUR := createOptionMap(true, true, true)
	wrapToEnableDisable(&optsPSUR)
	optsPSUR.SetDesc = "Enable failing hooks with an error when any\n" +
		"shared hooks configured is missing."
	optsPSUR.UnsetDesc = "Disable failing hooks with an error when any\n" +
		"shared hooks configured is missing."
	optsPSUR.Reset = "" // disable reset.

	configSetOptions(nonExistSharedCmd, setOpts, &optsPSUR, ctx.Log, 0, 0)

	nonExistSharedCmd.Flags().BoolVar(&gitOpts.Local, "local", false, "Use the local Git configuration (default).")
	nonExistSharedCmd.Flags().BoolVar(&gitOpts.Global, "global", false, "Use the global Git configuration.")

	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, nonExistSharedCmd))
}

func configDetectedLFSCmd(ctx *ccm.CmdContext, configCmd *cobra.Command, setOpts *SetOptions, gitOpts *GitOptions) {

	deleteDetectedLFSCmd := &cobra.Command{
		Use:   "delete-detected-lfs-hooks [flags]",
		Short: "Change the behavior for detected LFS hooks during install.",
		Long: `By default, detected LFS hooks during install are
disabled and backed up.`,
		Run: func(cmd *cobra.Command, args []string) {
			runDeleteDetectedLFSHooks(ctx, setOpts)
		}}

	optsPSUR := createOptionMap(true, true, true)
	wrapToEnableDisable(&optsPSUR)

	optsPSUR.SetDesc = "Remember to always delete detected LFS hooks\n" +
		"instead of the default behavior."
	optsPSUR.UnsetDesc = "Remember to always not delete detected LFS hooks and\n" +
		"to resort to the default behavior."
	optsPSUR.ResetDesc = "Resets the decision to the default behavior."

	configSetOptions(deleteDetectedLFSCmd, setOpts, &optsPSUR, ctx.Log, 0, 0)

	configCmd.AddCommand(ccm.SetCommandDefaults(ctx.Log, deleteDetectedLFSCmd))
}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	configCmd := &cobra.Command{
		Use:    "config",
		Short:  "Manages various Githooks configuration.",
		Long:   `Manages various Githooks configuration.`,
		PreRun: ccm.PanicWrongArgs(ctx.Log)}

	gitOpts := GitOptions{}
	setOpts := SetOptions{}

	configListCmd(ctx, configCmd, &gitOpts)
	configDisableCmd(ctx, configCmd, &setOpts, &gitOpts)
	configTrustCmd(ctx, configCmd, &setOpts)

	configSearchDirCmd(ctx, configCmd, &setOpts)
	configUpdateCmd(ctx, configCmd, &setOpts)
	configUpdateTimeCmd(ctx, configCmd, &setOpts)
	configCloneUrlCmd(ctx, configCmd, &setOpts)
	configCloneBranchCmd(ctx, configCmd, &setOpts)

	configSharedCmd(ctx, configCmd, &setOpts, &gitOpts)
	configNonExistSharedRepo(ctx, configCmd, &setOpts, &gitOpts)

	configDetectedLFSCmd(ctx, configCmd, &setOpts, &gitOpts)

	return ccm.SetCommandDefaults(ctx.Log, configCmd)
}
