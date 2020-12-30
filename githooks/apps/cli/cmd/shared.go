package cmd

import (
	"github.com/spf13/cobra"
)

// sharedCmd represents the shared command.
var sharedCmd = &cobra.Command{
	Use:   "shared",
	Short: "Manages the shared hook repositories.",
	Long: `
Manages the shared hook repositories set either in the '.githooks.shared'
file locally in the repository or in the local or global
Git configuration 'githooks.shared'.

git hooks shared add|remove [--shared|--local|--global] <git-url>
git hooks shared clear [--shared|--local|--global|--all]
git hooks shared purge
git hooks shared list [--shared|--local|--global|--all]
git hooks shared update|pull`,
	Run: panicWrongArgs,
}

const optsMess = `If '--local|--global' is given, then the 'githooks.shared' local/global Git configuration
is modified, or if the '--shared' option (default) is set, the '.githooks/.shared'
file is modified in the local repository.`

var sharedAddCmd = &cobra.Command{
	Use:   "add",
	Short: `Add shared repositories.`,
	Long: "Adds an item, given as '<git-url>' to the shared repositories list." + "\n" +
		optsMess,
	Run: func(cmd *cobra.Command, args []string) {
		runSharedAdd(false)
	}}

var sharedRemoveCmd = &cobra.Command{
	Use:   "remove",
	Short: `Remove shared repositories.`,

	Long: "Remove an item, given as '<git-url>' from the shared repositories list." + "\n" +
		optsMess,
	Run: func(cmd *cobra.Command, args []string) {
		runSharedAdd(true)
	}}

var sharedClearCmd = &cobra.Command{
	Use:   "clear",
	Short: `Clear shared repositories.`,
	Long: "Clears every item in the shared repositories list." + "\n" +
		optsMess + "\n" +
		"The '--all' option clears all three lists.",
	Run: func(cmd *cobra.Command, args []string) {
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
	Use:   "list",
	Short: `List shared repositories.`,
	Long:  `List the shared, local, global or all (default) shared hooks repositories.`,
	Run: func(cmd *cobra.Command, args []string) {
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

func runSharedAdd(remove bool) {
}

func runSharedClear() {
}

func runSharedPurge() {
}

func runSharedList() {
}

func runSharedUpdate() {
}

func init() { // nolint: gochecknoinits
	rootCmd.AddCommand(sharedCmd)
}
