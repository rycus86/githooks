package common

// IExecutable defines the interface for a general executable.
type IExecutable interface {
	GetCommand() string
	GetArgs(args ...string) []string
}

// Executable contains the data to a script/executbale file.
type Executable struct {
	// The absolute path of the script/executable.
	Path string
	// The run command for the script/executable, `nil` if its an executable.
	RunCmd []string
}

// GetCommand gets the first command.
func (e *Executable) GetCommand() string {
	if len(e.RunCmd) == 0 {
		return e.Path
	}
	return e.RunCmd[0]
}

// GetArgs gets all args.
func (e *Executable) GetArgs(args ...string) []string {
	s := append([]string{e.Path}, args...)
	if len(e.RunCmd) > 0 {
		return append(e.RunCmd[1:], s...)
	}
	return s
}
