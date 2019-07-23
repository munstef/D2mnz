module collections.set;

import std.typecons : Tuple, tuple;
import numerics : isIn, isNotIn;
import meta;
import numerics.algorithm;

struct Set(V) { // Set of items of type V

	enum bool sorted = is_comparable!V;

	protected V[] array;

	void insert(const V v) {
	    static if(sorted) {
            void insert(size_t lo, size_t hi) {
                if (lo > hi) return array[0.. hi] ~ value ~ array[hi .. $]	;
                size_t mid = lo + (hi - lo) / 2;
                if (value > array[mid]) insert(lo, mid - 1);
                if (value < array[mid]) insert(mid + 1, hi);
            }
            if (array.length) insert(0, array.length); array = [v];
	    } else {
            if (!v.isIn(array)) array ~= v;
		}
	}

	this(this) {
		array = this.array.dup;

	}

	this(V[] arg...){
		array = [];
		foreach(v; arg) insert(v);
	}

	V opIndex(const size_t index) const {
		enforce(index < array.length, "out of range");
		return array[index];
	}

	enum Set empty = Set();

	ref Set opAssign()(const Set s) {
		array = s.array.dup;
		return this;
	}

	bool opBinaryRight(string op : "in")(const V v) const {
		static if(sorted) return Binary.isIn(array, v);
		else return v.isIn(array);
	}

	Nullable!V indexOf(V key) {
	    static if(sorted) return Binary.indexOf(key);
	    else {
            size_t index;
            return key.isIn(array, index) ? index : null;
	    }
	}

	ref Set opOpAssign(string op)(const V v) if (op == "+" || op == "|") {
		insert(v, array);
		return this;
	}

	ref Set opOpAssign(string op)(const Set s) if (op == "+" || op == "|") {
		static if(soreted) array = Binary.mergeUnion(array, s.array);
		else {
			foreach(x; s.array) insert(x);
			return this;
		}
	}

    ref Set opOpAssign(string op : "&")(const V v) {
		if(v in this) array = [v]; else array = [];
	}

	ref Set opOpAssign(string op : "&")(const Set s) {
		if (sorted) array = Binary.mergeEq(array, s.array);
		else {
			for(size_t i = 0; i < array.length; ++i) {
				if (array[i] !in s) array = array[0 .. i] ~ array[i + 1 .. $];
			}
		}
		return this;
	}

    ref opOpAssign(string op : "^")(const V v) {
        static if(sorted) array = Binary.xor_insert(array, v);
        else {
            size_t index;
            if(v.isIn(array, index)) array = array[0 .. index] ~ array[index + 1 .. $]; else array ~= v;
        }
		return this;
	}

    ref opOpAssign(string op : "^")(const Set s) {
        static if(sorted) array = mergeNE(array, s.array);
        else {
            size_t index;
            foreach(v; s.array) if(v.isIn(array, index)) array = array[0 .. index] ~ array[index + 1 .. $]; else array ~= v;
        }
		return this;
	}

    ref opOpAssign(string op : "-")(const V v) const {
		static if(sorted) array = Binary.erase(array, v);
		else foreach(i, a; array) if (a == v) { array = array[0 .. i] ~ array[i + 1 .. $]; return this;}
		return this;
	}

	ref Set opOpAssign(string op : "-")(const Set s) {
        static if(sorted) array = mergeANB(array, s.array);
		else
            foreach(v; s.array)
                foreach(i, a; array) if (a == v) { array = array[0 .. i] ~ array[i + 1 .. $]; return this;}
		return this;
	}

	Set opBinary(string op)(const V v) const if (op == "+" || op == "|") {
		Set result = this;
		result += v;
		return result;
	}

	Set opBinaryRight(string op)(const V v) const if (op == "+" || op == "|") {
		Set result = this;
		result += v;
		return result;
	}

	Set opBinary(string op)(const Set s) const if (op == "+" || op == "|") {
		Set result = this;
		result += s;
		return result;
	}

	Set opBinary(string op : "&")(const Set s) const {
		Set result = this;
		return result &= s;
	}

	Set opBinary(string op : "&")(const V k) const {
		if (k in this) return Set(k); else return Set();
	}

	Set opBinaryRight(string op : "&")(const V k) const {
		if (k in this) return Set(k); else return Set();
	}

	Set opBinary(string op : "^")(const Set s) const {
		Set r = this;
		return r ^= s;
	}

	Set opBinary(string op : "^")(const V k) const {
		Set r = this;
		return this ^= k;
	}

	Set opBinaryRight(string op : "^")(const V k) const {
		Set r = this;
		return this ^= k;
	}

	Set opBinary(string op : "-")(const V v) const {
		Set r = this;
		return r -= v;
	}

    Set opBinaryRight(string op : "-")(const V v) const {
        if(v in this) return Set(); else return Set(v);
	}

	Set opBinary(string op : "-")(const Set s) const {
		Set r = this;
		return r -= s;
	}

	Set!(Tuple!(V, U)) opBinary(U, string op : "*")(const Set!U s) const {
		Set!(Tuple!(V, U)) r;
		foreach(x; array) foreach(y; s.array) r.array ~= tuple(x, y);
		return r;
	}

	Set!(Tuple!(V, U)) opBinary(U, string op : "*")(const U u) const {
		Set!(Tuple!(V, U)) result;
		foreach(a; array) result += tuple(a, u);
		return result;
	}

	Set!(Tuple!(U, V)) opBinaryRight(U, string op : "*")(const U u) const {
		Set!(Tuple!(U, V)) result;
		foreach(a; array) result += tuple(u, a);
		return result;
	}

	auto opBinary(string op : "^^")(uint n) const {
	    return pow!n(this);
	}

	bool isEmpty() const { return !array.length;}

	bool opBinary(string op : "in")(const Set s) const {
		if(array.length > s.array.length) return false;
		foreach(v; array) if(v !in s) return false;
        return true;
	}

	bool opEquals(const Set s) const {
		if (array.length != s.array.length) return false;
		return this in s;
	}

	U opCast(U : T[])() const {
		return array.dup;
	}

	int opApply(scope int delegate(V) dg) {
		int result = 0;
		foreach(V value; set.array) if(result = dg(value)) break;
		return result;
	}
	int opApply(scope int delegate(size_t, V) dg) {
		int result = 0;
		size_t index = 0;
		foreach(V value; array) {
			if(result = dg(index, value)) break;
			++index;
		}
		return result;
	}

	struct Range {
		ref Set set;
		size_t index;

		private this(ref Set s) { set = s; index = 0;}

		V front() const {
			return array[index];
		}

		void popFront() const {
			++index;
		}
		bool isEmpty() const {
			return index >= set.array.length;
		}

		int opApply(scope int delegate(V) dg) {
			int result = 0;
			foreach(V value; set.array) if(result = dg(value)) break;
			return result;
		}
		int opApply(scope int delegate(size_t, V) dg) {
			int result = 0;
			size_t index = 0;
			foreach(V value; array) {
				if(result = dg(index, value)) break;
				++index;
			}
			return result;
		}
	}

	@property auto range() const {
		return Range(this);
	}

	M opCast(M : MultiSet!V)() const {
		M res;
		foreach(v; array) res[v] = 1;
		return res;
	}

}

Set!(Tuple!(T, T)) sqr(S : Set!T, T)(const S s) { return s * s; }

auto pow(T, uint n : 0)(const Set!T s) {
	return Set();
}

auto pow(T, uint n : 1)(const Set!T s) {
	return s;
}

auto pow(T, uint n : 2)(const Set!T s) {
	return sqr!T(s);
}

auto pow(T, uint n)(const Set!T s) if(n % 2) {
	return s * sqr!T(pow!(T, n/2)(s));
}

auto pow(T, uint n)(const Set!T s) if(!(n % 2)) {
	return sqr!T(pow!(T, n/2)(s));
}

size_t card(S : Set!T, T)(const S s) {return s.length; }
alias norm(S : Set!T, T) = card!S;

Set!U power(U : Set!T, T)(const U s) {
	ReturnType ret;
	foreach(e; s.array) {
		ReturnType rs;
		foreach(x; ret.array) rs += x + e;
		ret += rs;
	}
	return ret;
}

struct MultiSet(V) {
	uint[V] array;

	this(V[] list...) {
		int* p;
		foreach(v; list) {
			p = (v in array);
			if (p !is null) ++(*p); else array[v] = 1;
		}
	}

	enum MultiSet = empty();

	ref MultiSet opAssign(const Set!V S) {
	    array.clear;
	    foreach(v; S) array[v] = 1;
		return this;
	}

	ref MultiSet opAssign(in MultiSet S) {
		array = S.array.dup;
	}
	ref MultiSet opAssign(in V v) {
		array.clear; array[v] = 1; return this;
	}
	ref MultiSet opAssign(in V[] list) {
		array.clear;
		return this(list);
	}

	ref MultiSet opOpAssign(string op :"&")(const MultiSet S) {
		foreach(k, v; S.array) if (k in array) array[k] = min(v, S.array[k]);
		return this;
	}

	ref MultiSet opOpAssign(string op :"+")(const MultiSet S) {
		foreach(k, v; S.array) if (k in array) array[k] += v; else array[k] = v;
		return this;
	}

	ref MultiSet opOpassign(string op : "|")(const MultiSet S) {
		foreach(k, v; S.array) if (k in array) array[k] = max(value, S.array[v]); else array[k] = v;
		return this;
	}

	ref MultiSet opOpassign(string op : "-")(const MultiSet S) {
		foreach(k, v; S.array) if (k in array) {
			if(array[k] > v) array[k] -= v; else array.remove(k);
		}
		return this;
	}

	ref MultiSet opOpassign(string op : "^")(const MultiSet S) {
		foreach(k, v; S.array) if (k in array) {
		    if(array[k] = v) array.remove(k);
			else if(array[k] > v) array[k] -= v;
			else if(array[k] < v) array[k] = v - array[k];
		}
		return this;
	}

	ref MultiSet opOpAssign(string op : "*")(in uint n) {
		if (n) foreach(v; array) array[v] *= n; else array.clear;
		return this;
	}

	MultiSet opBinary(string op : "*")(in uint n) {
		MultiSet res = this;
		return res *= n;
	}

	MultiSet opBinaryRight(string op : "*")(in uint n) {
		MultiSet res = this;
		return res *= n;
	}

	MultiSet opBinary(string op)(const MultiSet S) const if(op == "&" || op == "|" || op == "^" ||
															op == "+" || op == "-") {
		MultiSet res = this;
		return res.opOpAssign!op(S);
	}

	uint opBinaryRight(string op : "in")(const V v) const {
		uint* p;
		p = (v in array);
		return p is null ? 0 : *p;
	}

	MultiSet!(Tuple!(V, U)) opBinary(string op : "*", U)(const MultiSet!U S) {
		ReturnType res;
		foreach(k1, v1; array)
			foreach(k2, v2; S.array) res.array[tuple(k1, k2)] = v1 * v2;
		return res;
	}

	MultiSet!(Tuple!(Repeat!(n, V))) opBinary(string op : "^^")(in uint n) {
		ReturnType res;
		uint exp = n;
		switch(n) {
			case O : return res; break;
			case 1 : return this; break;
			case 2 : return Sqr(this); break;
			default : if (n % 2) return S * Sqr(S ^^ (n / 2)); else return Sqr(S ^^ (n / 2));
		}
	}
	S opCast(S : Set!V)() const {
		return Set!V(array.key);
	}

	bool opEqual(const MultiSet S) const {
		if (array.length == S.array.length) {
			foreach(k, v; array) if (v != (k in S)) return false;
			return true;
		} else return false;
	}

	bool opBinary(string op : "in",)(const MultiSet S) {
	    if(array.length > S.array.length) return false;
		foreach(k, v; array) if (v > (k in S)) return false;
		return true;
	}

	int opApply(int delegate(V v) dg) const {
		int result = 0;
		foreach(k, v; array) for(uint i = 0; i < v; i++) if(result = dg(v)) return result;
		return result;
	}

	int opApply(int delegate(uint, V) dg) const {
		int result = 0;
		foreach(k, v; array) if (result = dg(k, v)) return result;
		return result;
	}

	Range range() const @property {
		return Range(array);
	}

	struct Range {
		ref uint[V] list;

		private this(ref uint[V] array) {
			list = array;
			size_t k = 0;
            size_t v = 0;
		}
		bool empty() const @property {
			return (k >= list.length);
		}
		V front() const {
			return list.key[k];
		}

		void popFront() const {
			++v;
			if (v > list.value[k]) {
				v = 0;
				k++;
			}
		}
	}
}

MultiSet!(Tuple!(V, V)) sqr(V)(const MultiSet!V S) {
	ReturnType res;
	foreach(v; S.array) foreach(w; S.array) res[tuple(v, w)] = S[v] * S[w];
	return res;
}

uint card(V)(const MultiSet!V S) {
	return S.array.length;
}

uint norm(V)(const MultiSet!V S) {
	uint n = 0;
	foreach(v; S.array) n += v;
	return n;
}

Set!V supp(V)(const MultiSet!V S) {
	return S.to!(Set!V);
}

MultiSet!U power(U: MultiSet!T, T)(const U s) {
	MultiSet!U ret;
	foreach(e; s) {
		MultiSet!U rs;
		foreach(x; ret) rs += x + e;
		ret += rs;
	}
	return ret;
}
