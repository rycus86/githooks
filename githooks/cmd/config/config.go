package config

import (
	ccm "rycus86/githooks/cmd/common"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"

	"github.com/spf13/cobra"
)

type GitOptions struct {
	Local  bool
	Global bool
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

func wrapToEnableDisable(opts *OptionsMapping) (res OptionsMapping) {
	res = *opts
	res.Set = "enable"
	res.Unset = "disable"

	return
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

func runList(gitOpts *GitOptions) {

}

func runDisable(opts *SetOptions) {

}

func runSearchDir(opts *SetOptions) {

}

func runSharedRepos(opts *SetOptions, gitOpts *GitOptions) {

}

func runCloneUrl(opts *SetOptions, branch *string) {

}

func runUpdateTime(opts *SetOptions) {

}

func runTrust(opts *SetOptions) {

}

func runUpdate(opts *SetOptions) {

}

func runNonExistSharedRepos(opts *SetOptions) {

}

func NewCmd(ctx *ccm.CmdContext) *cobra.Command {

	configCmd := &cobra.Command{
		Use:    "config",
		Short:  "Manages various Githooks configuration.",
		Long:   `Manages various Githooks configuration.`,
		PreRun: ccm.PanicWrongArgs(ctx.Log)}

	gitOpts := GitOptions{}
	setOpts := SetOptions{}

	optsPrintSetUnsetReset := createOptionMap(true, true, true)
	optsPrintSetReset := createOptionMap(true, false, true)
	optsPrintSet := createOptionMap(true, false, false)
	optsPrintReset := createOptionMap(false, false, true)

	listCmd := &cobra.Command{
		Use:   "list [flags]",
		Short: "Lists settings of the Githooks configuration.",
		Long: `Lists the Githooks related settings of the Githooks configuration.
Can be either global or local configuration, or both by default.`,
		PreRun: ccm.PanicIfAnyArgs(ctx.Log),
		Run: func(cmd *cobra.Command, args []string) {
			if !gitOpts.Local && !gitOpts.Global {
				gitOpts.Local = true
				gitOpts.Global = true
			}
			runList(&gitOpts)
		}}
	listCmd.Flags().BoolVar(&gitOpts.Local, "local", false, "Use the local Git configuration.")
	listCmd.Flags().BoolVar(&gitOpts.Global, "global", false, "Use the global Git configuration.")
	configCmd.AddCommand(listCmd)

	disableCmd := &cobra.Command{
		Use:   "disable [flags]",
		Short: "Disables Githooks in the current repository.",
		Long: `Disables Githooks in the current repository.
LFS hooks and replaced previous hooks are still executed.
This command needs to be run at the root of a repository.`,
		Run: func(cmd *cobra.Command, args []string) {
			runDisable(&setOpts)
		}}
	configSetOptions(disableCmd, &setOpts, &optsPrintSetReset, ctx.Log, 0, 0)
	configCmd.AddCommand(disableCmd)

	searchDirCmd := &cobra.Command{
		Use:   "search-dir [flags]",
		Short: "Changes the search directory used during installation.",
		Long: `Changes the previous search directory setting
used during installation.`,
		Run: func(cmd *cobra.Command, args []string) {
			runSearchDir(&setOpts)
		}}
	configSetOptions(searchDirCmd, &setOpts, &optsPrintSetReset, ctx.Log, 1, 1)
	configCmd.AddCommand(searchDirCmd)

	var branch string
	cloneUrlCmd := &cobra.Command{
		Use:   "clone-url [flags]",
		Short: "Changes the Githooks clone url used for any update.",
		Long:  `Changes the Githooks clone url used for any update.`,
		Run: func(cmd *cobra.Command, args []string) {
			runCloneUrl(&setOpts, &branch)
		}}
	cloneUrlCmd.Flags().StringVar(&branch, "branch", "", "Branch to use for the clone url.")
	configSetOptions(cloneUrlCmd, &setOpts, &optsPrintSet, ctx.Log, 1, 1)
	configCmd.AddCommand(cloneUrlCmd)

	cloneBranchCmd := &cobra.Command{
		Use:   "update-time [flags]",
		Short: "Changes the Githooks update time.",
		Long: `Changes the Githooks update time used to check for updates.

Resets the last Githooks update time with the '--reset' option,
causing the update check to run next time if it is enabled.
Use 'git hooks update [--enable|--disable]' to change that setting.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUpdateTime(&setOpts)
		}}
	configSetOptions(cloneBranchCmd, &setOpts, &optsPrintReset, ctx.Log, 0, 0)
	configCmd.AddCommand(cloneBranchCmd)

	trustCmd := &cobra.Command{
		Use:   "trusted [flags]",
		Short: "Change trust settings in the current repository.",
		Long: `Change the trust setting in the current repository.

This command needs to be run at the root of a repository.`,
		Run: func(cmd *cobra.Command, args []string) {
			runTrust(&setOpts)
		}}
	trustOpts := optsPrintSetUnsetReset
	trustOpts.Set = "accept"
	trustOpts.SetDesc = "Accepts changes to all existing and new hooks\n" +
		"in the current repository when the trust marker\nis present."
	trustOpts.Unset = "deny"
	trustOpts.UnsetDesc = "Marks the repository as it has refused to\n" +
		"trust the changes, even if the trust marker is present."
	trustOpts.ResetDesc = "Clears the trust setting."
	configSetOptions(trustCmd, &setOpts, &trustOpts, ctx.Log, 0, 0)
	configCmd.AddCommand(trustCmd)

	updateCmd := &cobra.Command{
		Use:   "update [flags]",
		Short: "Change Githooks update settings.",
		Long:  `Enable or disable automatic Githooks updates.`,
		Run: func(cmd *cobra.Command, args []string) {
			runUpdate(&setOpts)
		}}
	updateOpts := wrapToEnableDisable(&optsPrintSetUnsetReset)
	updateOpts.SetDesc = "Enables automatic update checks for Githooks."
	updateOpts.UnsetDesc = "Disables automatic update checks for Githooks."
	updateOpts.Reset = "" // disable reset.
	configSetOptions(updateCmd, &setOpts, &updateOpts, ctx.Log, 0, 0)
	configCmd.AddCommand(updateCmd)

	sharedCmd := &cobra.Command{
		Use:   "shared [flags] [<git-url>...]",
		Short: "Updates the list of local or global shared hook repositories.",
		Long: `Updates the list of local or global shared hook repositories.

The '--set' option accepts multiple '<git-url>' arguments,
each containing a clone URL of a shared hook repository.
The '--reset' option clears this setting.
The '--print' option (default) outputs the current setting.`,
		Run: func(cmd *cobra.Command, args []string) {
			if !gitOpts.Local && !gitOpts.Global {
				gitOpts.Global = true
			}
			runSharedRepos(&setOpts, &gitOpts)
		}}
	sharedCmd.Flags().BoolVar(&gitOpts.Local, "local", false, "Use the local Git configuration.")
	sharedCmd.Flags().BoolVar(&gitOpts.Global, "global", false, "Use the global Git configuration (default).")
	configSetOptions(sharedCmd, &setOpts, &optsPrintSetReset, ctx.Log, 1, -1)
	configCmd.AddCommand(sharedCmd)

	nonExistSharedCmd := &cobra.Command{
		Use:   "fail-on-non-existing-shared-hooks [flags]",
		Short: "Updates the list of local or global shared hook repositories.",
		Long: `Enable or disable failing hooks with an error when any
shared hooks are missing. This usually means 'git hooks shared update'
has not been called yet.`,
		Run: func(cmd *cobra.Command, args []string) {
			runNonExistSharedRepos(&setOpts)
		}}
	nonExistOpts := wrapToEnableDisable(&optsPrintSetUnsetReset)
	nonExistOpts.SetDesc = "Enable failing hooks with an error when any\n" +
		"shared hooks configured is missing."
	nonExistOpts.UnsetDesc = "Disable failing hooks with an error when any\n" +
		"shared hooks configured is missing."
	nonExistOpts.Reset = "" // disable reset.
	configSetOptions(nonExistSharedCmd, &setOpts, &nonExistOpts, ctx.Log, 0, 0)
	configCmd.AddCommand(nonExistSharedCmd)

	deleteDetectedLFSCmd := &cobra.Command{
		Use:   "delete-detected-lfs-hooks [flags]",
		Short: "Change the behavior for detected LFS hooks during install.",
		Long: `By default, detected LFS hooks during install are
disabled and backed up.`,
		Run: func(cmd *cobra.Command, args []string) {
			runNonExistSharedRepos(&setOpts)
		}}
	detectLFSOpts := wrapToEnableDisable(&optsPrintSetUnsetReset)
	detectLFSOpts.SetDesc = "Remembers to always delete detected LFS hooks\n" +
		"instead of the default behavior."
	detectLFSOpts.UnsetDesc = "Remembers to always not delete detected LFS hooks and\n" +
		"to resort to the default behavior."
	detectLFSOpts.ResetDesc = "Resets the decision to the default behavior. " // disable reset.
	configSetOptions(deleteDetectedLFSCmd, &setOpts, &detectLFSOpts, ctx.Log, 0, 0)
	configCmd.AddCommand(deleteDetectedLFSCmd)

	return ccm.SetCommandDefaults(ctx.Log, configCmd)
}
