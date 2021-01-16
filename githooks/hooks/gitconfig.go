package hooks

// Git config keys for globals config.
const (
	GitCK_InstallDir = "githooks.installDir"
	GitCK_Runner     = "githooks.runner"
	GitCK_Disable    = "githooks.disable"

	GitCK_MaintainOnlyServerHooks = "githooks.maintainOnlyServerHooks"

	GitCK_AutoUpdateEnabled        = "githooks.autoUpdateEnabled"
	GitCK_AutoUpdateCheckTimestamp = "githooks.autoUpdateCheckTimestamp"
	GitCK_AutoUpdateUsePrerelease  = "githooks.autoUpdateUsePrerelease"

	GitCK_BugReportInfo = "githooks.bugReportInfo"

	GitCK_ChecksumCacheDir = "githooks.checksumCacheDir"

	GitCK_CloneBranch     = "githooks.cloneBranch"
	GitCK_CloneUrl        = "githooks.cloneUrl"
	GitCK_BuildFromSource = "githooks.buildFromSource"
	GitCK_GoExecutable    = "githooks.goExecutable"

	GitCK_DeleteDetectedLFSHooksAnswer = "githooks.deleteDetectedLFSHooks"
	GitCK_FailOnNonExistingSharedHooks = "githooks.failOnNonExistingSharedHooks"

	GitCK_UseCoreHooksPath        = "githooks.useCoreHooksPath"
	GitCK_PathForUseCoreHooksPath = "githooks.pathForUseCoreHooksPath"

	GitCK_PreviousSearchDir = "githooks.previousSearchDir"
	GitCK_NumThreads        = "githooks.numThreads"

	GitCK_AliasHooks = "alias.hooks"
)

// Git config keys for local config.
const (
	GitCK_Registered = "githooks.registered"
	GitCK_TrustAll   = "githooks.trustAll"
)

// Git config keys for local/global config.
const (
	GitCK_Shared               = "githooks.shared"
	GitCK_SharedUpdateTriggers = "githooks.sharedHooksUpdateTriggers"
)

// GetGlobalGitConfigKeys gets all global git config keys relevant for Githooks.
func GetGlobalGitConfigKeys() []string {
	return []string{
		GitCK_InstallDir,
		GitCK_Runner,
		GitCK_Disable,

		GitCK_MaintainOnlyServerHooks,
		GitCK_PreviousSearchDir,

		GitCK_AutoUpdateEnabled,
		GitCK_AutoUpdateCheckTimestamp,
		GitCK_AutoUpdateUsePrerelease,

		GitCK_BugReportInfo,

		GitCK_ChecksumCacheDir,

		GitCK_CloneBranch,
		GitCK_CloneUrl,
		GitCK_GoExecutable,
		GitCK_BuildFromSource,

		GitCK_DeleteDetectedLFSHooksAnswer,
		GitCK_FailOnNonExistingSharedHooks,

		GitCK_UseCoreHooksPath,
		GitCK_PathForUseCoreHooksPath,

		GitCK_NumThreads,

		GitCK_AliasHooks,

		// User and global.
		GitCK_Shared,
		GitCK_SharedUpdateTriggers}
}

// GetLocalGitConfigKeys gets all local git config keys relevant for Githooks.
func GetLocalGitConfigKeys() []string {
	return []string{
		GitCK_Registered,
		GitCK_TrustAll,

		GitCK_Shared,
		GitCK_SharedUpdateTriggers}
}
