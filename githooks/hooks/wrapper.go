package hooks

import (
	"os"
	"path"
	"regexp"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
)

var runWrapperDetectionRegex = regexp.MustCompile("https://github.com/rycus86/githooks")

// IsRunWrapper answers the question if `filePath`
// is a Githooks hook template file.
func IsRunWrapper(filePath string) (bool, error) {
	return cm.MatchLineRegexInFile(filePath, runWrapperDetectionRegex)
}

// GetRunWrapperReplacementName returns the file name of a replaced custom Git hook.
func GetRunWrapperReplacementName(fileName string) string {
	return fileName + "replaced.githooks"
}

// GetRunWrapperContent gets the bytes of the hook template.
func getRunWrapperContent() ([]byte, error) {
	return build.Asset("base-template-wrapper.sh")
}

// WriteRunWrapper writes the run wrapper to the file `filePath`.
func WriteRunWrapper(filePath string) (err error) {
	runWrapperContent, err := getRunWrapperContent()
	cm.AssertNoErrorPanic(err, "Could not get embedded run wrapper content.")

	file, err := os.Create(filePath)
	if err != nil {
		return
	}
	defer file.Close()

	_, err = file.Write(runWrapperContent)
	if err != nil {
		return err
	}
	err = file.Sync()
	if err != nil {
		return err
	}

	// Make executable
	_ = file.Close()
	err = cm.MakeExecutbale(filePath)

	return err
}

var lfsDetectionRe = regexp.MustCompile(`(git\s+lfs|git-lfs)`)

// HookDisableOption are the options
// how to disable a hook.
type HookDisableOption int

const (
	// BackupHook defines that a hook file gets backuped.
	BackupHook HookDisableOption = 1
	// DeleteHook defines that a hook file gets deleted.
	DeleteHook HookDisableOption = 2
)

func disableHookIfLFSDetected(
	filePath string,
	disableCallBack func(file string) HookDisableOption) (disabled bool, err error) {

	found, err := cm.MatchLineRegexInFile(filePath, lfsDetectionRe)
	if err != nil {
		return
	}

	if found {
		disableOption := disableCallBack(filePath)

		switch disableOption {
		default:
			fallthrough
		case BackupHook:
			err = os.Rename(filePath, filePath+".disabled.githooks")
			disabled = true
		case DeleteHook:
			err = os.Remove(filePath)
			disabled = true
		}

		if err != nil {
			return
		}
	}

	return
}

// InstallRunWrappers installs run wrappers for the given `hookNames` in `dir`.
// Existing hooks get renamed.
func InstallRunWrappers(
	dir string,
	hookNames []string,
	disableHookIfLFS func(file string) HookDisableOption) (err error) {

	for _, hookName := range hookNames {

		dest := path.Join(dir, hookName)

		isTemplate := false

		// Check there is already a Git hook in place and replace it.
		if cm.IsFile(dest) {

			isTemplate, err = IsRunWrapper(dest)

			if err != nil {
				err = cm.CombineErrors(err,
					cm.Error("Could not detect if '%s' is a Githooks run template."))
				return //nolint:nlreturn
			}

			if !isTemplate {

				// Try to detect a potential LFS statements and disable the hook.
				if disableHookIfLFS != nil {
					_, e := disableHookIfLFSDetected(dest, disableHookIfLFS)
					if e != nil {
						err = e
						return //nolint:nlreturn
					}
				}

				// Move the file normally if it is still existing.
				if cm.IsFile(dest) {
					newDest := path.Join(dir, GetRunWrapperReplacementName(hookName))

					err = os.Rename(dest, newDest)
					if err != nil {
						err = cm.CombineErrors(err,
							cm.ErrorF("Could not rename file '%s' to '%s'.", dest, newDest))
						return //nolint:nlreturn
					}
				}
			}
		}

		err = WriteRunWrapper(dest)
		if err != nil {
			err = cm.CombineErrors(err,
				cm.ErrorF("Could not write run wrapper to '%s'.", dest))
			return //nolint:nlreturn
		}
	}

	return
}
