// +build !mock

package main

import (
	"path"
	"runtime"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/updates"
	"rycus86/githooks/updates/download"
)

func downloadBinaries(
	log cm.ILogContext,
	settings *Settings,
	tempDir string,
	tag string) updates.Binaries {

	publicPGP, err := build.Asset(".deploy-pgp")
	log.AssertNoErrorPanicF(err, "Could not get deploy PGP key.")

	err = download.DownloadGithub("gabyx", "githooks", tag, tempDir, string(publicPGP))
	log.AssertNoErrorPanicF(err, "Could not download binaries.")

	ext := ""
	if runtime.GOOS == "windows" {
		ext = ".exe"
	}

	all := []string{
		path.Join(tempDir, "installer"+ext),
		path.Join(tempDir, "uninstaller"+ext),
		path.Join(tempDir, "cli"+ext),
		path.Join(tempDir, "runner"+ext)}

	return updates.Binaries{All: all, Installer: all[0], Others: all[1:]}
}
