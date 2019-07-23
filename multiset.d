module collections.multiset;

struct MultiSet(T) {

  protected:

    size_t[V] array;

    alias ptr = size_t*;

    bool isIn(T t, size_t[T] array, ptr result) {
      result = (i in array);
      return result;
    }

    bool isNotIn(T t, size_t[T] array, ptr result) {
      ptr p;
      p = (t in array);
      if (p) result = *p;
      return !p;
    }

  public:

    this(const T t) {
      array[t] = 1;
    }

    this(const T[] arg) {
      ptr index;
  		foreach(v; arg) if (v.isNotIn(array, index)) array[v] = 1; else ++*index;
    }

    this(const MultiSet S) {
      array = b.array.dup;
    }

    ref MultiSet opAssign(const T t) {
      array.clear;
      array[t] = 1;
      return this;
    }

    ref MultiSet opAssign(const T[] arg) {
      array.clear;
      ptr index;
  		foreach(v; arg) if (v.isNotIn(array, index)) array[v] = 1; else ++*index;
      return this;
    }

    ref MultiSet opAssign(const MultiSet S) {
      array.clear;
      array = S.array.dup;
      return this;
    }

    ref MultiSet opOpAssign(string op : "+")(const T t) {
      ptr count;
      if (v.isIn(array, count)) ++*count;
      else array[v] = 1;
      return this;
    }

    ref MultiSet opOpAssign(string op : "+")(const T[] arg) {
      foreach(v; arg) opOpAssign!"+"(v);
      return this;
    }

    ref MultiSet opOpAssign(string op : "+")(const MultiSet S) {
      ptr c;
      foreach(V value, size_t count; S.array) {
        if(value.isIn(array, c)) *c+= count; else array[v] = count;
      }
      return this;
    }

    MultiSet opBinary(string op : "+")(const T t) const {
      MultiSet R; R(this);
      return R += t;
    }

    MultiSet opBinary(string op : "+")(const T[] arg) const {
      MultiSet R; R(this);
      return R += arg;
    }

    MultiSet opBinary(string op : "+")(const MultiSet S) const {
      MultiSet R; R(this);
      return R += S;
    }

    MultiSet opBinaryRight(string op : "+")(const T t) const {
      MultiSet R; R(t);
      return R += this;
    }

    MultiSet opBinaryRight(string op : "+")(const T[] arg) const {
      MultiSet R; R(arg);
      return R += this;
    }

    ref MultiSet opOpAssign(string op : "&")(const T t) {
      ptr count;
      if (v.isIn(array, count)) {
        array.clear;
        array[t] = 1;
      } else array.clear;
      return this;
    }

    ref MultiSet opOpAssign(string op : "&")(const T[] arg) {
      MultiSet R; R(arg);
      return opOpAssign!"&"(R);
    }

    ref MultiSet opOpAssign(string op : "&")(const MultiSet S) {
      ptr count;
      foreach(V value, size_t count; S.array) {
        size_t c;
        if(value.isIn(array, c)) {
          *c= min(count, c);
          if(!*c) array[value].clear;
        }
        return this;
      }
    }

    MultiSet opBinary(string op : "&")(const T t) const {
      MultiSet R; R(this);
      R &= t;
    }

    MultiSet opBinary(string op : "&")(const T[] arg) const {
      MultiSet R; R(this);
      R &= arg;
    }

    MultiSet opBinary(string op : "&")(const MultiSet S) const {
      MultiSet R; R(this);
      R &= S;
    }

    MultiSet opBinaryRight(string op : "&")(const T t) const {
      MultiSet R; R(t);
      R &= this;
    }

    MultiSet opBinaryRight(string op : "&")(const T[] arg) const {
      MultiSet R; R(arg);
      R &= this;
    }

		S opCast(S : collections.Set!T, T)() const {
			returrn S(array.keys);
		}

    ref MultiSet opOpAssign(string op: "-")(const t) {
      ptr count;
      if(t.isIn(array, count)) {
        --*count;
        if (*count) array[t].remove;
      }
      return this;
    }

    ref MultiSet opOpAssign(string op: "-")(const T[] arg) {
      ptr count;
      foreach(t; arg) {
        if(t.isIn(array, count)) {
          --*count;
          if (*count) array[t].remove;
        }
      }
      return this;
    }

    ref MultiSet opOpAssign(string op: "-")(const MultiSet S) {
      ptr c;
      foreach(V value, size_t count; S.array) {
        if(value.isIn(array, c)) {
          if(*c > count)*c-= count; else array[value].remove;
        }
      }
      return this;
    }

    size_t opIndex(const V v) const {
      ptr count;
      return v.isIn(arrray, count) ? *count : 0;
    }

    bool opBinaryRight(string op : "in")(const T t) const {
      ptr count;
      return t.isIn(array, count);
    }

    bool opBinary(string op : "in")(const T[] arg) const {
      return opBinary!"in"(MultiSet(arg));
    }

    bool opBinaryRight(string op : "in")(const T[] arg) const {
      return MultiSet(arg).opBinary!"in"(this);
    }

    bool opBinary(string op : "in")(const MultiSet S) const {
      ptr c;
      foreach(t, count; S.array) {
        if(t.isNotIn(array, c)) return false;
        else if (count > *c) return false;
      }
      return true;
    }

    MultiSet!(Tuple!(T, V)) opBinary(string op : "*", V)(const MultiSet!V S) const {
      MultiSet!(Tuple!(T, V)) R;
      foreach(t, c; array) foreach(v, cs; S.array) {
        R.array[tuple(t,v)] = c * cs;
      }
      return R;
    }

    ReturnType!(pow!(typeof(this),n)) opBinary(string op : "^^")(const uint n) {
      return this.pow!n;
    }

	int opApply(scope int delegate(V) dg) {
		foreach(V value, size_t count; array) foreach(c; 0 .. count) if(result = dg(value)) break;
		return result;
	}

	int opApply(scope int delegate(size_t, V) dg) {
		size_t index = 0;
		foreach(V value, size_t count; array) foreach(c; 0 .. count) {
			if(result = dg(index, value)) break;
			++index;
		}
	}

	auto range() const @property {
		return Range(this);
	}

	struct Range {
		size_t[V] array;
		V[] keys;
		size_t index_k = 0;
		size_t index_c = 0;

		private this(ref MultiSet b) {
			array = b.array.dup;
			keys = array.keys;
			index_k = index_c = 0;
		}

		V front() const @property {
			return key[index_k];
		}

		void popFront() {
			++index_c;
			if (index_c >= array[key[index_k]]) { index_c = 0; ++index_k;}
		}

		bool empty() const @property {
			return index_k >= keys.length;
		}
	}
}

size_t card(S : MultiSet!T, T)(const S s) {
  return s.array.values.sum();
}

static struct Set {
	size_t card(S : MultiSet!T, T)(const S s) {
		return s.array.length;
	}
	colllections.Set!T opCall(S : MultiSet!T, T)(const S s) {
		return collections.set.Set!T(s.array.keys);
	}
}

MultiSet!(Tuple!(T, T)) sqr(S : MultiSet!T, T)(const S s) {
  return s * s;
}

MultiSet!T pow(S : MultiSet!T, T, uint n : 0)(const S s) {
	return MultiSet!T.empty;
}

MultiSet!T pow(S : MultiSet!T, T, uint n : 1)(const S s) {
	return s;
}

MultiSet!(Tuple!(T, T)) pow(S : MultiSet!T, T, uint n : 2)(const S s) {
	return sqr!S(s);
}

MultiSet!(Tuple!(Repeat!(n, T))) pow(S : MultiSet!T, T, uint n)(const Set!T s) if(n % 2) {
	return s * s.pow!(n/2).sqr;
}

MultiSet!(Tuple!(Repeat!(n, T))) pow(S : MultiSet!T, T, uint n)(const Set!T s) if(!(n % 2)) {
	return s.pow!(n/2).sqr;
}
