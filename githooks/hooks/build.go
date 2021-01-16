// +build !mock
// +build !debug

package hooks

const (
	// UseThreadPool defines if a threadpool is used to execute the hooks.
	UseThreadPool = true
)

// AllowLocalURLInRepoSharedHooks defines if local urls such as `file://` should
// be allowed in repository configured shared hooks.
func AllowLocalURLInRepoSharedHooks() bool {
	return false
}

// GetDefaultCloneURL returns the default clone url.
func GetDefaultCloneURL() string {
	return "https://github.com/gabyx/githooks.git"
}

// GetDefaultCloneBranch returns the default clone branch name.
func GetDefaultCloneBranch() string {
	return "master"
}
