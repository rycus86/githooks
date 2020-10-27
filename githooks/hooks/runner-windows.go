// +build windows

package hooks

// On Windows, executing with the default shell `sh` will only work for shell scripts
// since there is no notion of a shebang on windows we do the same by launching with `-c`
// which starts the shell and reads the shebang line on windows.
// We assume here that a shell like git-bash.exe from https://gitforwindows.org/
// is installed.
var defaultRunner = []string{"sh", "-c"}
