package common

import "strings"

// IExecutable defines the interface for a general executable.
type IExecutable interface {
	GetCommand() string
	GetArgs(args ...string) []string
}

// Executable contains the data to a script/executable file.
type Executable struct {
	// The absolute path of the script/executable.
	Path string

	// The optional run command for the script/executable,
	// `nil` if its an executable.
	RunCmd []string

	// If `RunCmd` is given tells if the input path is quoted "'<path>'"
	// meaning the runner receives a quoted path as last input.
	QuotePath bool
}

// GetCommand gets the first command.
func (e *Executable) GetCommand() string {
	if len(e.RunCmd) == 0 {
		return e.Path
	}

	return e.RunCmd[0]
}

// GetArgs gets all args.
// If `eRunCmd` contains a variable '${hookPath}'
// it will be replaced by 'Path'.
// The arguments `args` are appended last.
func (e *Executable) GetArgs(args ...string) []string {

	switch len(e.RunCmd) {
	case 0:
		return args
	case 1:
		return append([]string{e.getPath()}, args...)
	default:
		var pathUsed bool

		// Replace '${hookPath}' if existing after
		// first entry in 'RunCmd'.
		for i := range e.RunCmd[1:] {
			if strings.Contains(e.RunCmd[i], "${hooksPath}") {
				e.RunCmd[i] = strings.ReplaceAll(e.RunCmd[i], "${hooksPath}", e.Path)
				pathUsed = true
			}
		}

		// Append the hook path after all 'args...'
		if pathUsed {
			return append(e.RunCmd[1:], args...)
		} else {
			args = append([]string{e.getPath()}, args...)

			return append(e.RunCmd[1:], args...)
		}
	}
}

func (e *Executable) getPath() string {
	if e.QuotePath {
		return "'" + e.Path + "'"
	}

	return e.Path
}
