// +build !mock

package main

import (
	"path"
	"runtime"
	cm "rycus86/githooks/common"
	"rycus86/githooks/updates"
	"rycus86/githooks/updates/download"
)

func downloadBinaries(
	log cm.ILogContext,
	settings *Settings,
	tempDir string,
	status updates.ReleaseStatus) updates.Binaries {

	err := download.DownloadGithub("gabyx", "githooks", status.UpdateTag, tempDir)
	log.AssertNoErrorPanicF(err, "Could not download binaries.")

	ext := ""

	if runtime.GOOS == "windows" {
		ext = ".exe"
	}

	all := []string{
		path.Join(tempDir, "cli"+ext),
		path.Join(tempDir, "runner"+ext),
		path.Join(tempDir, "uninstaller"+ext),
		path.Join(tempDir, "installer"+ext)}

	// @todo Validate and checksum

	return updates.Binaries{All: all, Installer: all[3], Others: all[0:3]} // nolint:nlreturn
}
