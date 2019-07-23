module collections.multiarray;

struct Array(T, sizes ...) if (sizes.length > 1){
	enum size_t dim = sizes.length;
	enum size_t dimentions = dim;
	enum size_t order = dim;
	enum length = sizes.product;
	union {
		meta.traits.array!(T, sizes) _;
		T[length] __;
	}

	struct Indice {
		size_t begin;

	}

	this(T x) {
		__[] = x;
	}
	this(F...)(F components) if(F.length > 1) {
		foreach(i, v; components) static if(i < length) __[i] = components;
	}

	this(Array arr) {
		__ = arr.__;
	}

	ref Array opAssign(const Array arr) {
		__ = arr.__;
		return this;
	}

	ref T opIndex(size_t i) 
	in { 
		enforce(i < length, "opIndex: array index out of bounds");
	}
	do {
		return __[i];
	}

	ref auto opSlice() {return __[];}

	ReturnTypeUnary!(T, op) opIndexUnary(string op)(size_t i)
	in { 
		enforce(i < length, "opIndex: array index out of bounds");
	}
	do {
		return mixin(op ~ "__[i]");
	}

	ReturnTypeUnary!(T, op) opIndexUnary(string op)() { 
		return mixin(op ~"__[]");
	}

	ref T opIndexAssign(T t, size_t i)
	in {
		enforce(i < length, "opIndexAssign: array index out of bounds");
	}
	do {
		return __[i] = t;
	}

	ref Array opIndexAssign(T n) {
		__[] = n;
		return this;
	}

	ref ReturnTypeBinary!(T, op) opIndexOpAssign(string op)(T t, size_t  i) if(SameReturnTypeBinary!(T, op))
	in {
		enforce(i < length, "opIndexAssign: array index out of bounds");
	}
	do {
		return mixin("__[i] " ~ op ~ "= t");
		
	}
	ref Array opIndexOpAssign(string op)(T t) if(SameReturnTypeBinary!(T, op)) {
		mixin("__[] " ~ op ~ "= t");
		return this;
	}

	size_t opDollar(size_t n)() const if(n < sizes) {
		return sizes[n];
	}

	T opIndex(I...)(in I indices) const if(I.length == sizes.length) {
		size_t index = 0;
		size_t m = 1;
		foreach(i, ind; indices) {
			enforce(ind < sizes[i], "index out of range");
			index += ind * m;
			m *= sizes[i];
		}
		return __[index];
	}

	ref T opIndexAssign(I...)(in T t, in I indices) const if(I.length == sizes.length) {
		size_t index = 0;
		size_t m = 1;
		foreach(i, ind; indices) {
			enforce(ind < sizes[i], "index out of range");
			index += ind * m;
			m *= sizes[i];
		}
		return __[index] = t;
	}

	ref T opIndexUnary(string op, I...)(in T t, in I indices) const if(SameReturnTypeUnary!(T, op) && (I.length == sizes.length)) {
		size_t index = 0;
		size_t m = 1;
		foreach(i, ind; indices) {
			enforce(ind < sizes[i], "index out of range");
			index += ind * m;
			m *= sizes[i];
		}
		return opIndexUnary!op(t, index);
	}

	ref T opIndexOpAssign(string op, I...)(in T t, in I i) const if(SameReturnTypeBinary!(T, op) && (I.length == sizes.length)) {
		size_t index = 0;
		size_t m = 1;
		foreach(i, ind; indices) {
			enforce(ind < sizes[i], "index out of range");
			index += ind * m;
			m *= sizes[i];
		}
		return opIndexOpAssign!op(t, index);
	}

}
