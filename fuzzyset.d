module collections.fuzzyset;

struct FuzzySet(T, F = double) if(is_floating!F) {
	const pure nothrow F delegate(in T) contains;


}
