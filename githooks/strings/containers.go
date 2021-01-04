package strs

// AppendUnique appends the string to the array
// if its not existing. The bool indicates if an append occurred.
func AppendUnique(slice []string, elems ...string) (sl []string, appended int) {
	sl = slice

	for _, s := range elems {
		if Includes(sl, s) {
			continue
		}

		appended += 1
		sl = append(sl, s)
	}

	return
}

// MakeUnique makes the slice containing only unique items.
func MakeUnique(slice []string) []string {
	s := make(StringSet, len(slice))
	for _, el := range slice {
		s.Insert(el)
	}

	return s.ToList()
}

// Remove removes all occurrences from the slice.
// The int indicates if a remove occurred.
func Remove(slice []string, s string) (newitems []string, removed int) {
	newitems = make([]string, 0, len(slice))

	for _, el := range slice {
		if el != s {
			newitems = append(newitems, el)
		} else {
			removed++
		}
	}

	return newitems, removed
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

type StringSet map[string]bool

// Add adds `s` to the set.
func (m StringSet) Insert(s string) {
	m[s] = true
}

// Remove removes `s` from the set.
func (m StringSet) Remove(s string) {
	m[s] = false
}

// Exists checks existence of `s` in the set.
func (m StringSet) Exists(s string) bool {
	return m[s]
}

// Gets the keys of a string set.
func (s *StringSet) ToList() (keys []string) {
	keys = make([]string, len(*s))

	i := 0
	for k := range *s {
		keys[i] = k
		i++
	}

	return
}
