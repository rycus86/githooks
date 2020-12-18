package hooks

import (
	"bufio"
	"os"
	"regexp"
	"rycus86/githooks/build"
	cm "rycus86/githooks/common"
)

var runWrapperDetectionRegex = regexp.MustCompile("https://github.com/rycus86/githooks")

// IsRunWrapper answers the question if `filePath`
// is a Githooks hook template file.
func IsRunWrapper(filePath string) (bool, error) {
	file, err := os.Open(filePath)
	if err != nil {
		return false, err
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		if runWrapperDetectionRegex.MatchString(scanner.Text()) {
			return true, nil
		}
	}

	if err := scanner.Err(); err != nil {
		return false, err
	}

	return false, nil
}

// GetRunWrapperReplacementName returns the file name of a replaced custom Git hook.
func GetRunWrapperReplacementName(fileName string) string {
	return fileName + "replaced.githooks"
}

// GetRunWrapperContent gets the bytes of the hook template.
func getRunWrapperContent() ([]byte, error) {
	return build.Asset("base-template-wrapper.sh")
}

// WriteRunWrapper writes the run wrapper to the file `filePath`
func WriteRunWrapper(filePath string) (err error) {
	runWrapperContent, err := getRunWrapperContent()
	cm.AssertNoErrorPanic(err, "Could not get embedded run wrapper content.")

	file, err := os.Create(filePath)
	if err != nil {
		return
	}
	defer file.Close()

	_, err = file.Write(runWrapperContent)
	if err != nil {
		return err
	}
	err = file.Sync()

	return err
}
