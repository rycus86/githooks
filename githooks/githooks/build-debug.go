// +build debug

package hooks

const (
	// AllowLocalURLInRepoSharedHooks defines if local urls such as `file://` should
	// be allowed in repository configured shared hooks.
	AllowLocalURLInRepoSharedHooks = true

	// UseThreadPool defines if a threadpool is used to execute the hooks.
	UseThreadPool = true
)
