package common

// Any returns `true` if one of the strings in the slice
// satisfies the predicate `f`.
func Any(vs []interface{}, f func(interface{}) bool) bool {
	for _, v := range vs {
		if f(v) {
			return true
		}
	}
	return false
}

// All returns `true` if all of the strings in the slice
// satisfy the predicate `f`.
func All(vs []interface{}, f func(interface{}) bool) bool {
	for _, v := range vs {
		if !f(v) {
			return false
		}
	}
	return true
}

// Filter returns a new slice containing all strings in the
// slice that satisfy the predicate `f`.
func Filter(vs []interface{}, f func(interface{}) bool) []interface{} {
	var vsf []interface{}
	for _, v := range vs {
		if f(v) {
			vsf = append(vsf, v)
		}
	}
	return vsf
}

// Map returns a new slice containing the results of applying
// the function `f` to each string in the original slice.
func Map(vs []interface{}, f func(interface{}) interface{}) []interface{} {
	vsm := make([]interface{}, len(vs))
	for i, v := range vs {
		vsm[i] = f(v)
	}
	return vsm
}
