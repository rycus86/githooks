// +build mock

package main

import (
	"os"
	"path"
	"rycus86/githooks/updates"
)

func downloadBinaries(
	settings *InstallSettings,
	tempDir string,
	status updates.ReleaseStatus) updates.Binaries {

	bin := os.Getenv("GITHOOKS_DOWNLOAD_BIN_DIR")

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
