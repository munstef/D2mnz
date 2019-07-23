module collections.span;

struct Span(T) {
	ref T[] array;
	size_t first, length;
	this(ref T[] array, size_t first, size_t size) {
		enforce(first < array.length, "first index is out of range of array");
		enforce(first + size <= array.length, "size is out of range of array");
		this.array = array;
		this.first = first;
		this.length = size;
	}
    this(const Span!T S, size_t first, size_t size) {
		enforce(first < S.length, "first index is out of range of array");
		enforce(first + size <= S.length, "size is out of range of array");
		this.array = S.array;
		this.first = S.first + first;
		this.length = size;
	}
	ref T opIndex(size_t index) {
		return array[first + index];
	}
	ref auto opIndex() {
		return this;
	}
	size_t[2] opSlice(size_t index1, size_t index2) { return [index1, index2];}

	ref auto opIndex(size_t[2] slice) {
		return Span!(T, array, first + slice[0], slice[1] - slice[0]);
	}
	enum size_t opDollar = length;
	bool opApply(int delegate(T) dg) {
	    int error;
	    foreach(v; array[first .. first + size]) if (error = dg(v)) return error;
	}
    bool opApply(int delegate(ref T) dg) {
	    int error;
	    foreach(ref v; array[first .. first + size]) if (error = dg(v)) return error;
	}
    bool opApply(int delegate(size_t, T) dg) {
	    int error;
	    foreach(v; array[first .. first + size]) if (error = dg(v)) return error;
	}
    bool opApply(int delegate(size_t, ref T) dg) {
	    int error;
	    foreach(index, ref v; array[first .. first + size]) if (error = dg(index - first,v)) return error;
	}
}

