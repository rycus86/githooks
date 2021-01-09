package updates

import (
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
)

// SetAutomaticUpdateSettings set the automatic update settings.
func SetAutomaticUpdateCheckSettings(enable bool, reset bool) error {
	opt := hooks.GitCK_AutoUpdateEnabled
	gitx := git.Ctx()

	switch {
	case reset:
		return gitx.UnsetConfig(opt, git.GlobalScope)
	case enable:
		return gitx.SetConfig(opt, true, git.GlobalScope)
	default:
		return gitx.SetConfig(opt, false, git.GlobalScope)
	}
}

// GetAutomaticUpdateSettings gets the automatic update settings.
func GetAutomaticUpdateCheckSettings() (enabled bool, isSet bool) {
	conf := git.Ctx().GetConfig(hooks.GitCK_AutoUpdateEnabled, git.GlobalScope)
	switch {
	case conf == "true":
		return true, true
	case conf == "false":
		return false, true
	default:
		return false, false
	}
}
