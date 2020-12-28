// +build mock

package main

import (
	"os"
	"path"
	cm "rycus86/githooks/common"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
)

func downloadBinaries(
	settings *Settings,
	tempDir string,
	status updates.ReleaseStatus) updates.Binaries {

	bin := os.Getenv("GITHOOKS_BIN_DIR")
	cm.PanicIf(strs.IsEmpty(bin), "GITHOOKS_BIN_DIR undefined")

	others := []string{
		path.Join(tempDir, "cli"),
		path.Join(tempDir, "runner"),
		path.Join(tempDir, "uninstaller")}
	installer := path.Join(tempDir, "installer")

	all := append(others, installer)

	for _, exe := range all {
		src := path.Join(bin, path.Base(exe))
		err := cm.CopyFile(src, exe)
		cm.AssertNoErrorPanicF(err, "Copy from '%s' to '%s' failed.", src, exe)
	}

	return updates.Binaries{
		Installer: installer,
		Others:    others,
		All:       all}
}
