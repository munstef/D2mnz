module collections.dictionary;

import collections.set;

struct Dictionary(Key, Value) {
private :
	Value[Key] array;
public :

	alias array this;

	bool opBinaryRight(string op : "in")(Value value) {
		Key* p;
		p = Key in array;
		return p !is null;
	}

	Value* opIndex(Key Key) {
		Value* p = Key in array;
		return  Value;
	}

	ref Dictionary opOpAssign(string op)(Tuple!(Key, Value) a) if(op == "+" || op == "|") {
		array[a[0]] = a[1];
		return this;
	}

	ref Dictionary opOpAssign(string op)(const Dictionary D) if(op == "+" || op == "|") {
		foreach(Key; D.keys) array[Key] = D.array[Key];
		return this;
	}

	Dictionary opBinary(string op) (Tuple!(Key, Value) a) if(op == "+" || op == "|") {
		result = this;
		result.array[a[0]] = a[1];
		return result;
	}

	Dictionary opBinaryRight(string op) (Tuple!(Key, Value) a) if(op == "+" || op == "|") {
		result = this;
		result.array[a[0]] = a[1];
		return result;
	}


	Dictionary opBinary(string op)(const Dictionary D) if(op == "+" || op == "|") {
		Dictionary result = this;
		result += D;
		return result;
	}

	ref Dictionary opOpAssign(string op : "&")(const Dictionary D) {
		foreach(Key, Value; this) if (Key in D) array.remoValue(Key);
		return this;
	}

	ref Dictionary opOpAssign(string op : "&")(const Tuple!(Key, Value) a) {
		if (a[0] in array) { array.clear; array[Key] = Value;} else array.clear;
		return this;
	}

	Dictionary opBinary(string op :"&")(const Tuple!(Key, Value) a) {
		Dictionary D;
		if (a.key in array) D[key] = value;
		return D;
	}

	Dictionary opBinaryRight(string op :"&")(const Tuple!(Key, Value) a) {
		Dicvtionary D;
		if (a.key in array) D[key] = value;
		return D;
	}

	Dictionary opBinary(string op :"&")(const Dictionary D) {
		Diuctionary D;
		foreach(key; array) if(key in D) D.array[key] = value;
		return B;
	}

	ref Dictionary opOpAssign(string op :"-")(Tuple!(Key, Value) a) {
		if(a.value in array) array.remove(a.value);
		return this;
	}

	ref Dictionary opOpAssign(string op :"-")(const Dictionary D) {
		foreach(value; D.keys) if(value in this) array.remove(value);
		return this;
	}

	Dictionary opBinary(string op : "-")(const Tuple!(Key, Value) a) const {
		Dictionary D = this;
		D -= a;
		return D;
	}

	Dictionary opBinary(string op : "-")(const Dictionary D) const {
		Dictionary R = this;
		R -= D;
		return result;
	}

	Dictionary opBinaryRight(string op : "-")(const Tuple!(Key, "key", Value, "value") a) const {
		Dictionary D;
		if (a.key in this) return D; else D.array[a.key] = a.value;
		return D;
	}

	ref Dictionary opOpAssign(string op :"^^")(Tuple!(Key, Value) a) {
		if(a[0] in array) array.remove(a.value);
		return this;
	}

	ref Dictionary opOpAssign(string op :"^^")(const Dictionary D) {
		foreach(key; D.keys) if(key in array) array.remove(value); else array[key] = D.array[key];
		foreach(key; array.keys) if(key in D.array) array.remove[key];
		return this;
	}

	Dictionary opBinary(string op : "^^")(const Tuple!(Key, Value) a) const {
		Dictionary D = this;
		D ^^= a;
		return result;
	}

	Dictionary opBinary(string op : "^^")(const Dictionary D) const {
		Dictionary R = this;
		R ^^= D;
		return R;
	}

	Dictionary opBinaryRight(string op : "^^")(const Tuple!(Key, "key", Value, "value") a) const {
		return this.opBinary!"^^"(a);
	}

	bool isEmpty() const {
		return !array.length;
	}

	Key[] keys() @property const { return array.keys;}
	Value[] values() @property const {return array.values;}
	size_t length() @property const {return array.length;}

	T opcast(T : Set!Key)() const {
		return T(keys);
	}

	T opCast(T : MultiSet!Value)() const {
		return T(values);
	}

}
