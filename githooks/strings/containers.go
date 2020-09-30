package strs

// AppendUnique appends the string to the array
// if its not existing
func AppendUnique(slice []string, s string) []string {
	for _, el := range slice {
		if el == s {
			return slice
		}
	}
	return append(slice, s)
}

// Remove removes all occurances from the slice.
func Remove(slice []string, s string) []string {
	newitems := []string{}

	for _, el := range slice {
		if el != s {
			newitems = append(newitems, el)
		}
	}

	return newitems
}

// Index returns the first index of the target string `t`, or
// -1 if no match is found.
func Index(vs []string, t string) int {
	for i, v := range vs {
		if v == t {
			return i
		}
	}
	return -1
}

// Includes returns `true` if the string t is in the
// slice.
func Includes(vs []string, t string) bool {
	return Index(vs, t) >= 0
}

// Any returns `true` if one of the strings in the slice
// satisfies the predicate `f`.
func Any(vs []string, f func(string) bool) bool {
	for _, v := range vs {
		if f(v) {
			return true
		}
	}
	return false
}

// All returns `true` if all of the strings in the slice
// satisfy the predicate `f`.
func All(vs []string, f func(string) bool) bool {
	for _, v := range vs {
		if !f(v) {
			return false
		}
	}
	return true
}

// Filter returns a new slice containing all strings in the
// slice that satisfy the predicate `f`.
func Filter(vs []string, f func(string) bool) []string {
	vsf := make([]string, 0)
	for _, v := range vs {
		if f(v) {
			vsf = append(vsf, v)
		}
	}
	return vsf
}

// Map returns a new slice containing the results of applying
// the function `f` to each string in the original slice.
func Map(vs []string, f func(string) string) []string {
	vsm := make([]string, len(vs))
	for i, v := range vs {
		vsm[i] = f(v)
	}
	return vsm
}
