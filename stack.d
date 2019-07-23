module collections.stack;

struct Stack(T) {
private:

	T[] array;

public:

	this(this) { array = array.dup;}

	this(const Stack S) { array = S.array.dup;}

	this(const T[] arg...) { array = arg.dup;}

	@property size_t length() const { return array.length;}

	@property bool empty() const { return !array.length;}

	T top() const @property
	in { assert(length);}
	do {
		return array[$-1];
	}

	T pop()
	in { assert(length);}
	do {
		r = array[$-1];
		--array.length;
		return r;
	}

	void popfront() {
	    --array.length;
	}

	void push(T value) { array ~=value; }

	T[] asArrayByDestacking() @property const {
		return array.dup.reverse;
	}
	T[] asArray() @property const {
		return array.dup;
	}

	Stack dup() const @property {
	    return Stack!T(this);
	}

	@property auto range() {
	    return dup;
	}

    int opApply(scope int delegate(T) dg) {
        int result = 0;
        foreach_reverse(t; array) if(result = dg(t)) return result;
        return result;
    }

}

struct Stack(T, size_t size) if(size > 0) {
private:

	T[size] array;
	size_t index = 0;

public:

	this(this) {
	    array = array.dup;
	    index = array.length;
    }

	this(const Stack S) { array = S.array.dup;}

	this(const T[] arg...) {
        enforce(arg.length <= size, "the stack is too small for the number of elements");
        array = arg.dup;
        index = array.length;
    }

	@property size_t length() const { return array.length;}

	@property bool empty() const { return index;}

	@property bool full() const { return index > size;}

	T top() const @property
    in { enforce(!empty, "stack is empty");}
	do {
		return array[index - 1];
	}

	T pop()
	in { enforce(!empty, "stack is empty");}
	do {
		return array[--index];
	}

	void popfront(){
      --index;
	}
	alias front = top;

	void push(T value)
	in { enforce (!full);}
	do {
	    array[index] = value;
	    ++index ;
    }

	T[] asArrayByDestacking() @property const {
		return array.dup.reverse;
	}
	T[] asArray() @property const {
		return array.dup;
	}

	int opApply(scope int delegate(T) dg) {
	    int result = 0;
	    foreach_reverse(t; array[0 .. index]) if(result = dg(t)) return result;
	    return result;
	}

	Stack dup() @property {
	    return Stack!(T, size)(this);
	}

	Stack range() @property {
	    return dup;
	}

}



