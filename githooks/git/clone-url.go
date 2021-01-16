package git

import "regexp"

var reURLScheme *regexp.Regexp = regexp.MustCompile(`(?m)^[^:/?#]+://`)
var reShortSCPSyntax = regexp.MustCompile(`(?m)^.+@(:P<host>.+):(:P<path>.+)`)
var reFileURLScheme = regexp.MustCompile(`(?m)^file://`)

// IsCloneUrlALocalPath checks if the clone url is local path.
// Thats the case if its not a URL Scheme or a short SCP syntax.
func IsCloneUrlALocalPath(url string) bool {
	return !(reURLScheme.MatchString(url) || reShortSCPSyntax.MatchString(url))
}

// ParseSCPSyntax parses the url as a short SCP syntax and reporting
// the host and path if not nil.
func ParseSCPSyntax(url string) []string {
	if m := reShortSCPSyntax.FindStringSubmatch(url); m != nil {
		return m[1:]
	}

	return nil
}

// IsCloneUrlALocalURL checks if the clone url is a url to a local directory.
// Thats the case only for `file://`.
func IsCloneUrlALocalURL(url string) bool {
	return reFileURLScheme.MatchString(url)
}
