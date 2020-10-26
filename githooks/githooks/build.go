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
