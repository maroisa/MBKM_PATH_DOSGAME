class_name WildcardMatcher
extends RefCounted
## Pencocok pola wildcard DOS/Windows CMD (* dan ?) secara case-insensitive.


static func matches(pattern: String, filename: String) -> bool:
	var p: String = pattern.strip_edges().to_lower()
	var f: String = filename.strip_edges().to_lower()
	if p.is_empty():
		return false
	return _match_here(p, 0, f, 0)


static func _match_here(p: String, pi: int, f: String, fi: int) -> bool:
	while pi < p.length():
		var pc: String = p[pi]
		if pc == "*":
			# Lewati asterisk beruntun.
			while pi + 1 < p.length() and p[pi + 1] == "*":
				pi += 1
			if pi == p.length() - 1:
				return true
			for k: int in range(fi, f.length() + 1):
				if _match_here(p, pi + 1, f, k):
					return true
			return false
		elif pc == "?":
			if fi >= f.length():
				return false
			# '?' mewakili tepat 1 karakter nama (tidak melompati pemisah ekstensi '.').
			if f[fi] == ".":
				return false
			pi += 1
			fi += 1
		else:
			if fi >= f.length() or pc != f[fi]:
				return false
			pi += 1
			fi += 1
	return fi == f.length()


static func evaluate_filter(pattern: String, allow_files: Array, deny_files: Array) -> Dictionary:
	var allow_matched: Array[String] = []
	var allow_missed: Array[String] = []
	var deny_leaked: Array[String] = []
	var deny_blocked: Array[String] = []

	for item: Variant in allow_files:
		var fname: String = str(item)
		if matches(pattern, fname):
			allow_matched.append(fname)
		else:
			allow_missed.append(fname)

	for item: Variant in deny_files:
		var fname: String = str(item)
		if matches(pattern, fname):
			deny_leaked.append(fname)
		else:
			deny_blocked.append(fname)

	var is_perfect: bool = allow_missed.is_empty() and deny_leaked.is_empty() and not pattern.strip_edges().is_empty()
	return {
		"perfect": is_perfect,
		"allow_matched": allow_matched,
		"allow_missed": allow_missed,
		"deny_leaked": deny_leaked,
		"deny_blocked": deny_blocked,
	}
