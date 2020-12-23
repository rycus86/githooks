package common

import (
	"bufio"
	"os"
	"regexp"
)

// MatchLineRegexInFile returns if the regex matches in the file `filePath`.
func MatchLineRegexInFile(filePath string, regex *regexp.Regexp) (found bool, err error) {
	file, err := os.Open(filePath)
	if err != nil {
		return
	}
	defer file.Close()

	scanner := bufio.NewScanner(file)

	for scanner.Scan() {
		if regex.MatchString(scanner.Text()) {
			found = true
			return // nolint:nlreturn
		}
	}

	err = scanner.Err()

	return
}
