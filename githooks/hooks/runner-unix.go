// +build !windows

package hooks

import cm "rycus86/githooks/common"

// GetDefaultRunner gets the default hook runner.
func GetDefaultRunner(hookPath string) cm.Executable {
	return cm.Executable{
		Path:      hookPath,
		RunCmd:    []string{"sh"},
		QuotePath: false}
}
