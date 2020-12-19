// +build !windows

package git

// GetDefaultTemplateDir gets the default Git template dir.
func GetDefaultTemplateDir() string {
	return "/usr/share/git-core/templates"
}
