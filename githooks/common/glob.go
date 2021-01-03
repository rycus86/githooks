package common

// From: https://github.com/yargevad/filepathx/edit/master/filepathx.go @907099cb

// Package filepathx adds double-star globbing support to the Glob
// function from the core path/filepath package.
// You might recognize "**" recursive globs from things
// like your .gitignore file, and zsh.
// The "**" glob represents a recursive wildcard
// matching zero-or-more directory levels deep.

import (
	"os"
	"path/filepath"
	strs "rycus86/githooks/strings"
	"strings"
)

// Globs represents one filepath glob, with its elements joined by "**".
type globs []string

// Glob adds double-star support to the core path/filepath Glob function.
// It's useful when your globs might have double-stars, but you're not sure.
// On Windows `\\` or '/' will work as a path separator in pattern.
// Adpated for syntax escaping and only "/" paths.
func Glob(pattern string, ignoreErrors bool) (l []string, err error) {
	if !strings.Contains(pattern, "**") {
		// passthru to core package if no double-star
		l, err = filepath.Glob(pattern)
	} else {
		l, err = globs(strings.Split(pattern, "**")).expand(ignoreErrors)
	}

	// Only Unix paths ...
	l = strs.Map(l, filepath.ToSlash)

	return

}

// Expand finds matches for the provided Globs.
func (g globs) expand(ignoreErrors bool) ([]string, error) {
	var matches = []string{""} // accumulate here

	for _, glob := range g {
		var hits []string
		var hitMap = map[string]bool{}
		for _, match := range matches {
			paths, err := filepath.Glob(match + glob)
			if err != nil {
				if ignoreErrors {
					continue
				}

				return nil, err
			}
			for _, path := range paths {
				err = filepath.Walk(path, func(path string, info os.FileInfo, err error) error {
					if err != nil {
						if ignoreErrors {
							return filepath.SkipDir
						} else {
							return err
						}
					}
					// save deduped match from current iteration
					if _, ok := hitMap[path]; !ok {
						path = strings.ReplaceAll(path, "*", "?")
						path = strings.ReplaceAll(path, "[", "?")
						path = strings.ReplaceAll(path, "]", "?")
						hits = append(hits, path)
						hitMap[path] = true
					}

					return nil
				})

				if err != nil {
					return nil, err
				}
			}
		}
		matches = hits
	}

	// fix up return value for nil input
	if g == nil && len(matches) > 0 && matches[0] == "" {
		matches = matches[1:]
	}

	return matches, nil
}
