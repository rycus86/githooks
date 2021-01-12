package hooks

import (
	"os"
	"path"
	"regexp"
	"runtime"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
)

var runWrapperDetectionRegex = regexp.MustCompile("https://github.com/rycus86/githooks")

// IsRunWrapper answers the question if `filePath`
// is a Githooks hook template file.
func IsRunWrapper(filePath string) (bool, error) {
	return cm.MatchLineRegexInFile(filePath, runWrapperDetectionRegex)
}

// GetHookReplacementFileName returns the file name of a replaced custom Git hook.
func GetHookReplacementFileName(fileName string) string {
	return path.Base(fileName) + ".replaced.githook"
}

// GetRunWrapperContent gets the bytes of the hook template.
func getRunWrapperContent() ([]byte, error) {
	return build.Asset(path.Join("githooks/run-wrapper.sh"))
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
		return
	}
	err = file.Sync()
	if err != nil {
		return
	}

	// Make executable
	_ = file.Close()
	err = cm.MakeExecutable(filePath)

	return
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
	disableCallBack func(file string) HookDisableOption) (disabled bool, deleted bool, err error) {

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
			// The file cannot be potentially be opened/read.
			// Only a run-wrapper can be running (triggering an update)
			// and a run-wrapper gets not detected as an LFS hook.
			err = os.Remove(filePath)
			disabled = true
			deleted = true
		}
	}

	return
}

// Moves existing hook `dest` to `dir(path)/GetHookReplacementFileName(dest)`
// if its not a Githooks run-wrapper.
// If it is a run-wrapper dont do anything.
func moveExistingHooks(
	dest string,
	disableHookIfLFS func(file string) HookDisableOption,
	log cm.ILogContext) error {

	// Check there is already a Git hook in place and replace it.
	if !cm.IsFile(dest) {
		return nil
	}

	isRunWrapper, err := IsRunWrapper(dest)

	if err != nil {
		return cm.CombineErrors(err,
			cm.ErrorF("Could not detect if '%s' is a Githooks run wrapper.", dest))
	}

	if !isRunWrapper {

		// Try to detect a potential LFS statements and
		// disable the hook (backup or delete).
		if disableHookIfLFS != nil {
			_, _, err := disableHookIfLFSDetected(dest, disableHookIfLFS)
			if err != nil {
				return err
			}
		}

		// Replace the file normally if it is still existing.
		if cm.IsFile(dest) {
			if log != nil {
				log.InfoF("Saving existing Git hook '%s'.", dest)
			}

			newDest := path.Join(path.Dir(dest), GetHookReplacementFileName(dest))
			err = os.Rename(dest, newDest)
			if err != nil {
				return cm.CombineErrors(err,
					cm.ErrorF("Could not rename file '%s' to '%s'.", dest, newDest))
			}
		}
	}

	return nil
}

// getHookDirTemp gets the Githooks temp. directory inside Git's hook directory.
func getHookDirTemp(hookDir string) string {
	return path.Join(hookDir, ".githooks-tmp")
}

// DeleteHookDirTemp deletes the temporary director inside the Git's hook directory.
func DeleteHookDirTemp(hookDir string) (err error) {
	dir := getHookDirTemp(hookDir)
	if cm.IsDirectory(dir) {
		return os.RemoveAll(dir)
	}

	return nil
}

// Cleans the temporary director inside the Git's hook directory.
func assertHookDirTemp(hookDir string) (dir string, err error) {
	dir = getHookDirTemp(hookDir)
	err = os.MkdirAll(dir, cm.DefaultFileModeDirectory)

	return
}

// InstallRunWrappers installs run wrappers for the given `hookNames` in `dir`.
// Existing custom hooks get renamed.
// All deleted hooks by this function get moved to the `tempDir` directory, because
// we should not delete them yet.
func InstallRunWrappers(
	dir string,
	hookNames []string,
	beforeSaveCallback func(file string),
	disableHookIfLFS func(file string) HookDisableOption,
	log cm.ILogContext) error {

	for _, hookName := range hookNames {

		dest := path.Join(dir, hookName)

		err := moveExistingHooks(dest, disableHookIfLFS, log)
		if err != nil {
			return err
		}

		beforeSaveCallback(dest)

		if cm.IsFile(dest) {
			// If still existing, it is a run-wrapper:

			// The file `dest` could be currently running,
			// therefore we move it to the temporary directly.
			// On Unix we could simply remove the file.
			// But on Windows, an opened file (mostly) cannot be deleted.
			// it might work, but is ugly.

			if runtime.GOOS == "windows" {
				backupDir, err := assertHookDirTemp(dir)
				if err != nil {
					return cm.CombineErrors(err,
						cm.ErrorF("Could not create temp. dir in '%s'.", dir))
				}

				moveDest := cm.GetTempPath(backupDir, "-"+path.Base(dest))
				err = os.Rename(dest, moveDest)
				if err != nil {
					return cm.CombineErrors(err,
						cm.ErrorF("Could not move file '%s' to '%s'.", dest, moveDest))
				}

			} else {
				// On Unix we simply delete the file, because that works even if the file is
				// open at the moment.
				err = os.Remove(dest)
				if err != nil {
					return cm.CombineErrors(err,
						cm.ErrorF("Could not delete file '%s'.", dest))
				}
			}

		}

		err = WriteRunWrapper(dest)
		if err != nil {
			return cm.CombineErrors(err,
				cm.ErrorF("Could not write Githooks run wrapper to '%s'.", dest))
		}
	}

	return nil
}

// UninstallRunWrappers deletes run wrappers in `dir`.
// Existing replaced hooks get renamed.
func UninstallRunWrappers(dir string, hookNames []string) (err error) {

	for _, hookName := range hookNames {

		dest := path.Join(dir, hookName)

		if !cm.IsFile(dest) {
			continue
		}

		isRunWrapper, e := IsRunWrapper(dest)

		if e != nil {
			err = cm.CombineErrors(err,
				cm.ErrorF("Run wrapper detection for '%s' failed.", dest))
		} else if isRunWrapper {
			// Delete the run wrapper
			e := os.Remove(dest)

			if e == nil {
				// Move replaced hook back in place.
				replacedHook := path.Join(path.Dir(dest), GetHookReplacementFileName(dest))
				if cm.IsFile(replacedHook) {
					if e := os.Rename(replacedHook, dest); e != nil {
						err = cm.CombineErrors(err,
							cm.ErrorF("Could not rename file '%s' to '%s'.",
								replacedHook, dest))
					}
				}

			} else {
				err = cm.CombineErrors(err, cm.ErrorF("Could not delete file '%s'.", dest))
			}
		}
	}

	return
}

// Installs LFS Hooks into `gitDir`.
func InstallLFSHooks(gitDir string) error {
	return git.CtxC(gitDir).Check("lfs", "install")
}
