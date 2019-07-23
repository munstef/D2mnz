module collections.bitset;

import std.typetuple, std.typecons;

struct Interval(int from, int to) {
    bool opBinaryRight(string op : "in")(const int n) {
        if (n >= begin && n <= end) return true;
    }
};


struct Set(int begin, size_t size) {

	uint[size / 16 + (size % 16 != 0)] array;

	private struct Index {
		size_t index, offset;

		this(int n) 
		in {assert(n >= begin && n - begin < size, "out of range");}
		do { index = (n - begin) / 16; offset = (n - begin) % 16;}

		alias index this;

		ref Index opAssign(const n)
		in {assert(n >= begin && n - begin < size, "out of range");}
		do { index = (n - begin) / 16; offset = (n - begin) % 16;}
	}
	this(const int[] arg...) {
	    array[] = 0;
	    Index index;
	    foreach(v; arg) {
	        index = v;
	        array[index] |= 1 << index.offset;
	    }
	}

	ref Set opAssign(const Set s) {
		array = s.array.dup;
		return this;
	}

	bool opBinaryRight(string op : "in")(const int n) const
	do {
		Index index(n);
		return array[index] & (1 << index.offset);
	}

	bool opOpAssign(string op)(const int n) const if (op == "+" || op == "|")
	{
		Index = index(n);
		array[index] |= (1 << index.offset);
		return this;
	}

	bool opOpAssign(string op)(const Set s) const if (op == "+" || op == "|") {
		foreach(i, v; array) array[i] |= s.array[i];
		return this;
	}

	ref Set opOpAssign(string op : "-")(const int n) {
		Index index(n);
		array[index] &= ~(1 << index.offset);
		return this;
	}

	ref Set opOpAssign(string op : "-")(const Set s) {
		foreach(i, ref v; array) v &= ~s.array[i];
		return this;
	}

	ref Set opOpAssign(string op : "&")(const int n) {
		Index index(n);
		array[index] &= 1 << index.offset;
		return this;
	}

	ref Set opOpAssign(string op : "&")(const Set s) {
		foreach(i, v; array) array[i] &= s.array[i];
		return this;
	}

	ref Set opOpAssign(string op : "^")(const int n) {
		Index index(n);
		if (array[index] & (1 << index.offset))
			array[index] &= ~(1 << index.offset);
		else array[index] |= 1 << index.offset;
		return this;
	}

	ref Set opOpAssign(string op : "^")(const Set s) {
		foreach(i, v; array) array[i] = v ^ s.array[i];
		return this;
	}

    Set opBinaryRight(string op)(const Set s) if(op == "+" || op == "|" || op == "&" || op == "^" || "-"){
	    Set result = this;
	    return result.opOpAssign!op(s);
	}

	Set opBinary(string op)(const n) if(op == "+" || op == "|" || op == "&" || op == "^" || "-"){
	    Set result = this;
	    return result.opOpAssign!op(n);
	}

    Set opBinaryRight(string op)(const n) if(op == "+" || op == "|" || op == "&" || op == "^"){
	    Set result = this;
	    return result.opOpAssign!op(n);
	}

	Set opBinaryRight(string op : "-")(const n) {
	    Index index(n);
	    return (array[index] & (1 << index.offset)) ? Set() : Set(n);
	}

	Set opUnary(string op : "~")() const {
		Set result;
		result.array = ~array[];
		return result;
	}



	Set opBinary(string op : "^")(const int n) const {
		Set result = this;
		return result ^= n;
	}

	Set opBinaryRight(string op : "^")(const int n) const  {
		Set result = this;
		return result ^= n;
	}

	Set opBinary(string op : "^")(const Set s) const {
		Set result = this;
		return result ^= s;
	}

	bool opBinary(string op : "in")(const Set s) const {
		 return (this & s) == s;
	}

	bool opEquals(const Set s) const {
		if (size % 16 == 0) {
			foreach(i, v; array) if (s.array[i] != v) return false;
			return true;
		} else {
			foreach(i; 0 .. array.length - 2) if (array[i] != s.array[i]) return false;
			foreach(i; 0 .. size % 16)
				if ((array[$ - 1] & (1 << i)) != (s.array[$-1] & (1 << i))) return false;
			return true;
		}
	}

	int opApply(scope int delegate(int) dg) {
		int result = 0;
		int item;
		foreach(i, v; array) foreach(off; 0 .. 15) {
			item = (i * 16 + off) + begin;
			if (item <= end) {
				if(v & (1 << off)) result = dg(item);
				if (result) break;
			} else break;
		}
		return result;
	}

	bool opIndex(int n) const {
		Index = index(n);
		return array[index] & (1 << index.offset);
	}

	ref Set opIndexAssign(bool v, int n) {
		Index = index(n);
		if(v) array[index] = array[index] | (1 << off); else array[index] = array[index] & ~(1 << index.offset);
		return this;
	}

	ref Set opIndexAssign(bool v) {
		if (v) foreach(i; array) i = 0xFFFF;
		else foreach(i; array) i = 0;
		return this;
	}

 	ref Set opOpIndexAssign(string op)(bool v, int n) if(op == "|" || op == "+" || op == "&" || op == "^" || op == "-") {
		return opAssign!op(n);
	}

	ref Set opOpIndexAssign(string op)(bool v) if(op == "|" || op == "+" || op == "&" || op == "^") {
		static if (op == "|" || op == "+") if (v) foreach(u; array) u = 0xFFFF;
		static if (op == "^") if (v) foreach(u; array) u = ~u;
		static if (op == "&") if (!v) foreach(u; array) u = 0;
		static if (op == "-") if (v) foreach(u; array) u = 0;
	}

	Set opIndexUnary(string op : "~")() {
		return opUnary!"~"();
	}

	size_t opDollar() { return size;}

}


