// +build !mock

package main

import (
	"net/url"
	"path"
	"runtime"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	strs "rycus86/githooks/strings"
	"rycus86/githooks/updates"
	"rycus86/githooks/updates/download"
	"strings"
)

// detectDeploySettings tries to detect the deploy settings.
// Currently that works for Github automatically.
// For Gitea you need to specify the deploy api `deployAPI`.
// Others will fail and need a special deploy settings config file.
func detectDeploySettings(cloneUrl string, deployAPI string) (download.IDeploySettings, error) {

	publicPGP, err := build.Asset(path.Join("githooks", ".deploy-pgp"))
	cm.AssertNoErrorPanic(err, "Could not get embedded deploy PGP.")

	isLocal := git.IsCloneUrlALocalPath(cloneUrl) ||
		git.IsCloneUrlALocalURL(cloneUrl)
	if isLocal {
		return nil, cm.ErrorF(
			"Url '%s' points to a local directory.", cloneUrl)
	}

	owner := ""
	repo := ""

	// Parse the url.
	host := ""
	if hostAndPath := git.ParseSCPSyntax(cloneUrl); hostAndPath != nil {
		// Parse SCP Syntax.
		host = hostAndPath[0]
		owner, repo = path.Split(hostAndPath[1])

		owner = strings.TrimSpace(strings.TrimPrefix(owner, "/"))
		repo = strings.TrimSpace(strings.TrimSuffix(repo, ".git"))

	} else {
		// Parse normal URL.
		url, err := url.Parse(cloneUrl)
		if err != nil {
			return nil, cm.ErrorF("Cannot parse clone url '%s'.", cloneUrl)
		}
		host = url.Host
		owner, repo = path.Split(url.Path)

		owner = strings.TrimSpace(strings.ReplaceAll(owner, "/", ""))
		repo = strings.TrimSpace(strings.TrimSuffix(repo, ".git"))
	}

	// For SCP we don't know the protocol, we take https as default.

	// If deploy API hint is not given,
	// define it by the parsed host.
	if strs.IsEmpty(deployAPI) {
		switch {
		case strings.Contains(host, "github"):
			deployAPI = "github"
		default:
			return nil,
				cm.ErrorF("Cannot auto-determine deploy API for host '%s'.", host)
		}
	}

	switch deployAPI {
	case "github":
		return &download.GithubDeploySettings{
			RepoSettings: download.RepoSettings{
				Owner:      owner,
				Repository: repo},
			PublicPGP: string(publicPGP)}, nil
	case "gitea":
		return &download.GiteaDeploySettings{
			APIUrl: "https://" + host + "/api/v1",
			RepoSettings: download.RepoSettings{
				Owner:      owner,
				Repository: repo},
			PublicPGP: string(publicPGP)}, nil
	default:
		return nil, cm.ErrorF("Deploy settings auto-detection for\n"+
			"deploy api '%s' not supported.",
			deployAPI)
	}

}

func downloadBinaries(
	log cm.ILogContext,
	deploySettings download.IDeploySettings,
	tempDir string,
	versionTag string) updates.Binaries {

	log.PanicIfF(deploySettings == nil,
		"Could not determine deploy settings.")

	err := deploySettings.Download(versionTag, tempDir)
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
