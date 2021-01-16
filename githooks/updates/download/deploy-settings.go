package download

import (
	"path"
	cm "rycus86/githooks/common"
)

// DeploySettings are the settings a user of Githooks can adjust to
// successfully download updates.
type deploySettings struct {
	Version int `yaml:"version"`

	Gitea  *GiteaDeploySettings  `yaml:"gitea"`
	Github *GithubDeploySettings `yaml:"github"`
	Http   *HttpDeploySettings   `yaml:"http"`
	Local  *LocalDeploySettings  `yaml:"local"`
}

const deploySettingsVersion = 1

type IDeploySettings interface {
	Download(versionTag string, dir string) error
}

// LoadDeploySettings load the deploy settings from `file`.
func LoadDeploySettings(file string) (IDeploySettings, error) {
	var settings deploySettings
	if err := cm.LoadYAML(file, &settings); err != nil {
		return nil, err
	}

	switch {
	case settings.Gitea != nil:
		return settings.Gitea, nil
	case settings.Github != nil:
		return settings.Github, nil
	case settings.Http != nil:
		return settings.Http, nil
	case settings.Local != nil:
		return settings.Local, nil
	}

	return nil, nil
}

// StoreDeploySettings stores the deploy `settings` to `file`.
func StoreDeploySettings(file string, settings IDeploySettings) error {

	var s deploySettings

	// Always store the new version
	s.Version = deploySettingsVersion

	switch v := settings.(type) {
	case *GiteaDeploySettings:
		s.Gitea = v
	case *GithubDeploySettings:
		s.Github = v
	case *HttpDeploySettings:
		s.Http = v
	case *LocalDeploySettings:
		s.Local = v
	default:
		cm.PanicF("Cannot store deploy settings for type '%T'", v)
	}

	return cm.StoreYAML(file, &s)
}

func GetDeploySettingsFile(installDir string) string {
	return path.Join(installDir, "deploy.yaml")
}
