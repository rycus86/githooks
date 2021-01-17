package builder

import (
	"os"
	"path"
	"regexp"
	"runtime"
	cm "rycus86/githooks/common"
	"rycus86/githooks/git"
	"rycus86/githooks/hooks"
	strs "rycus86/githooks/strings"
	"strings"

	"github.com/hashicorp/go-version"
)

var relPathGoSrc = "githooks"
var goVersionMin = "1.15.0"
var versionRe = regexp.MustCompile(`\d+\.\d+\.\d+`)

func findGoExec() (cm.CmdContext, error) {

	check := func(gox cm.CmdContext) error {

		verS, err := gox.Get("version")
		if err != nil {
			return cm.ErrorF(
				"Executable '%s' is not found.",
				gox.BaseCmd)
		}

		ver := versionRe.FindString(verS)
		if strs.IsEmpty(ver) {
			return cm.ErrorF(
				"Executable version of '%s' cannot be matched.",
				gox.BaseCmd)
		}

		verMin, err := version.NewVersion(goVersionMin)
		cm.DebugAssert(err == nil, "Wrong version.")

		verCurr, err := version.NewVersion(ver)
		if err != nil {
			return cm.ErrorF(
				"Executable version '%s' of '%s' cannot be parsed.",
				ver, gox.BaseCmd)
		}

		if verCurr.LessThan(verMin) {
			return cm.ErrorF(
				"Executable version of '%s' is '%s' -> min. required is '%s'.",
				gox.BaseCmd, ver, goVersionMin)
		}

		return nil
	}

	var gox cm.CmdContext
	var err error

	// Check from config.
	goExec := git.Ctx().GetConfig(hooks.GitCK_GoExecutable, git.GlobalScope)
	if strs.IsNotEmpty(goExec) && cm.IsFile(goExec) {
		gox = cm.CmdContext{BaseCmd: goExec}

		e := check(gox)
		if e == nil {
			return gox, nil
		}
		err = cm.CombineErrors(err, e)
	}

	// Check globally in path.
	gox = cm.CmdContext{BaseCmd: "go"}
	e := check(gox)
	if e == nil {
		return gox, nil
	}

	return cm.CmdContext{}, cm.CombineErrors(err, e)
}

// Build compiles this repos executable with Go and reports
// the output binary directory where all built binaries reside.
func Build(repoPath string, buildTags []string) (string, error) {

	goSrc := path.Join(repoPath, relPathGoSrc)
	if !cm.IsDirectory(goSrc) {
		return "", cm.Error("Source directors '%s' is not existing.", goSrc)
	}

	goPath := path.Join(repoPath, relPathGoSrc, ".go")
	goBinPath := path.Join(repoPath, relPathGoSrc, "bin")

	// Find the go executable
	gox, err := findGoExec()
	if err != nil {
		return goBinPath,
			cm.CombineErrors(
				cm.Error("Could not find a suitable 'go' executable."),
				err)
	}

	// Build it.
	e1 := os.RemoveAll(goPath)
	e2 := os.RemoveAll(goBinPath)
	if e1 != nil || e2 != nil {
		return goBinPath, cm.ErrorF("Could not remove temporary build files.")
	}

	// Set working dir.
	gox.Cwd = goSrc

	// Modify environment for compile.
	gox.Env = strs.Filter(os.Environ(), func(s string) bool {
		return !strings.Contains(s, "GOBIN") &&
			!strings.Contains(s, "GOPATH")
	})

	gox.Env = append(gox.Env,
		strs.Fmt("GOBIN=%s", goBinPath),
		strs.Fmt("GOPATH=%s", goPath))

	// Initialize modules.
	vendorCmd := []string{"mod", "vendor"}
	out, err := gox.GetCombined(vendorCmd...)
	if err != nil {
		return goBinPath,
			cm.ErrorF("Module vendor command failed:\n'%s %v'\nOutput:\n%s",
				gox.BaseCmd, vendorCmd, out)
	}

	// Genereate everything.
	generateCmd := []string{"generate", "-mod=vendor", "./..."}
	out, err = gox.GetCombined(generateCmd...)
	if err != nil {
		return goBinPath,
			cm.ErrorF("Generate command failed:\n'%s %v'\nOutput:\n%s",
				gox.BaseCmd, generateCmd, out)
	}

	// Compile everything.
	cmd := []string{"install", "-mod=vendor"}

	if runtime.GOOS == cm.WindowsOsName {
		buildTags = append(buildTags, cm.WindowsOsName)
	}

	if len(buildTags) != 0 {
		cmd = append(cmd, "-tags", strings.Join(buildTags, ","))
	}

	cmd = append(cmd, "./...")
	out, err = gox.GetCombined(cmd...)

	if err != nil {
		return goBinPath,
			cm.ErrorF("Compile command failed:\n'%s %v'\nOutput:\n%s",
				gox.BaseCmd, cmd, out)
	}

	return goBinPath, nil
}
