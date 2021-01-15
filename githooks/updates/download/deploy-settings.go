package download

import cm "rycus86/githooks/common"

// DeploySettings are the settings a user of Githooks can adjust to
// successfully download updates.
type DeploySettings struct {
	Version int `yaml:"version"`

	Gitea  *GiteaDeploySettings  `yaml:"gitea"`
	Github *GithubDeploySettings `yaml:"github"`
	Http   *HttpDeploySettings   `yaml:"http"`
}

const deploySettingsVersion = 1

// LoadDeploySettings load the deploy settings from `file`.
func LoadDeploySettings(file string) (settings DeploySettings, err error) {
	err = cm.LoadYAML(file, &settings)

	return
}

// StoreDeploySettings stores the deploy `settings` to `file`.
func StoreDeploySettings(file string, settings *DeploySettings) error {

	// Always store the new version
	settings.Version = deploySettingsVersion

	return cm.StoreYAML(file, settings)
}
