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

func getDefaultDeploySettings() (IDeploySettings, error) {

	publicPGP, err := build.Asset(path.Join("githooks", ".deploy-pgp"))
	if err != nil {
		return nil, err
	}

	return &download.GithubDeploySettings{
		Owner:      "gabyx",
		Repository: "githooks",
		PublicPGP:  string(publicPGP)}, nil
}

type IDeploySettings interface {
	Download(versionTag string, dir string) error
}

func getDeploySettings(log cm.ILogContext, settings *Settings) (IDeploySettings, error) {
	return getDefaultDeploySettings()
}

func downloadBinaries(
	log cm.ILogContext,
	settings *Settings,
	tempDir string,
	versionTag string) updates.Binaries {

	deploySettings, err := getDeploySettings(log, settings)
	log.AssertNoErrorPanicF(err, "Could not get deploy settings")

	err = deploySettings.Download(versionTag, tempDir)
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
