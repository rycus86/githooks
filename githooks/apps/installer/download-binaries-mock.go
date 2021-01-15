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
	log cm.ILogContext,
	settings *Settings,
	tempDir string,
	tag string) updates.Binaries {

	bin := os.Getenv("GITHOOKS_BIN_DIR")
	cm.PanicIf(strs.IsEmpty(bin), "GITHOOKS_BIN_DIR undefined")

	log.Info("Faking download: taking from '%s'.", bin)

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
