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
	settings *InstallSettings,
	tempDir string,
	status updates.ReleaseStatus) updates.Binaries {

	bin := os.Getenv("GITHOOKS_DOWNLOAD_BIN_DIR")
	cm.PanicIf(strs.IsEmpty(bin))

	others := []string{
		path.Join(bin, "cli"),
		path.Join(bin, "runner")}
	installer := path.Join(bin, "installer")

	all := append(others, installer)

	return updates.Binaries{
		Installer: installer,
		Others:    others,
		All:       all}
}
