module collections.condset;
//import meta;
import std.typecons : Tuple, tuple;
import std.meta : Repeat;
import meta.predicate : and;
import meta.list;

/* Set is define with a condition function if condition is true for an item
of T then this item is in this set */

struct Set(T) {

  const pure nothrow bool delegate (in T) contains;

	enum : Set { empty = Set(x => false), full = Set(x => true)};

	bool opBinaryRight(string op : "in")(in T x) const pure nothrow {
		return contains(x);
	}

	Set!(Tuple!(T, U)) opBinary(string op : "*", U)(const Set!U set) {
	    return Set!(Tuple!(T, U))(x => and!(contains, set.contains)(x.extends));
	}

	auto opBinary(string op : "^^")(const uint n) const {
	    if(n == 0) return empty;
	    else if (n == 1) return this;
	    else return Set!(Repeat!(n, T))(x => and!(Reapeat!(n,contains))(x.extend));
	}

	Set opBinary(string op)(in Set set) const pure nothrow if (op == "+" || op == "|") {
		return Set(x => contains(x) || set.contains(x));
	}

	Set opBinary(string op : "-")(in Set set) const pure nothrow {
		return Set(x => contains(x) && !set.contains(x));
	}

	Set opBinary(string op : "&")(in Set set) const pure nothrow {
		return Set(x => contains(x) && set.contains(x));
	}

	Set opBinary(string op : "^")(in Set set) const pure nothrow {
		return Set(x => contains(x) != set.contains(x));
	}

	Set opUnary(string op : "!")() const pure nothrow {
		return Set(x => !contains(x));
	}

    M opCast(M : MultiSet!T)() const {
		return M(x => contains(x) ? 1 : 0);
	}

    static if(is_comparable!T) {
        enum Sup(T, T a) = set!T(x => x >= a);
        enum Inf(T, T a) = set!T(x => x <= a);
        enum SupNeq(T, T a) = !Inf!(T, a);
        enum InfNeq(T, T a) = !Sup!(T, a);
        enum Neq(T, T a) = set!T(x => x != a);
    }

    static if(is_floating!T) {
        enum Rplus(T, T a = T(0)) = Sup!(T, a);
        enum Rminus(T, T a = T(0)) = Inf!(T, a);
        enum Rstar(T, T a = T(0)) = Neq!(T, a);
        enum Rplusstar(T, T a = T(0)) = SupNeq!(T, a);
        enum Rminusstar(T, T a = T(0)) = InfNeq!(T, a);
    }

    static if(is(T == quotient!U, U)) {
        enum Qplus(T, T a = T(0)) = Sup!(T, a);
        enum Qminus(T, T a = T(0)) = Inf!(T, a);
        enum Qstar(T, T a = T(0)) = Neq!(T, a);
        enum Qplusstar(T, T a = T(0)) = SupNeq!(T, a);
        enum Qminusstar(T, T a = T(0)) = InfNeq!(T, a);
    }

    static if(is_unsigned_integral!T) {
        enum N(T, T a) = Sup!(T, a);
        enum Nstar(T) = Neq!(T, T(0));
    }

    static if(is_signed_integral!T) {
        enum Zplus(T) = Sup!(T, T(0));
        enum Zminus(T) = Inf!(T, T(0));
        enum Zstar(T) = Neq!(T, T(0));
        enum Zplusstar(T) = SupNeq(T, T(0));
        enum Zminusstar(T) = InfNeq!(T, T(0));
    }

    static if(is_anion!T) {
        enum U(T) = Set!T(x => x.norm == T(1));
        enum star(T) = Set!T(x => !x.isZero);
    }
}

template Odd(T) if(is_integer!T) {
	enum Odd = Set!T(x % 2);
}

template Even(T) if(is_integer!T) {
	enum Even = ~ Odd!T;
}


/* MultiSet is define with a function returning an natural for an item of T
this number is the occurence of this item from this MultiSet */
struct MultiSet(T) {

	const pure nothrow uint delegate(in T) contains;

	enum : MultiSet { empty = MutiSet(x => 0)};

	MultiSet opBinary(string op : "+")(const MultiSet S) {
		return MultiSet(x => contains(x) + S.contains(x));
	}

	MultiSet opBinary(string op : "|")(const MultiSet S) {
		return MultiSet(x => max(contains(x), S.contains(x)));
	}

	MultiSet opBinary(string op : "&")(const MultiSet S) {
		return MultiSet(x => min(contains(x), S.contains(x)));
	}

	private uint sub(in Set S, in T) {
		uint m = contains(x);
		uint n = S.contains(x);
		return (m > n) ? m - n : 0;
	}

	private uint diff(in Set S, in T x) {
		uint m = contais(x);
		uint n = S.contains(x);
		return  m > n ? m - n : m - n;
	}

	MultiSet opBinary(string op : "-")(const MultiSet S) {
		return MultiSet(x => sub(S, x));
	}

	MultiSet opBinaryRight(string op : "*")(const size_t n) {
	    if (n = 0) return MultiSet(T(0));
		if(n = 1) return this;
		if(n > 1) return MultiSet(x => contains(x) * n);
		else return empty;
	}

	MultiSet!(Tuple!(T, U)) opBinary(string op : "*", U)(const MultiSet!U S) {
        return MultiSet(x => prod!(contains, S.contains)(x));
    }

    auto opBinary(string op : "^^")(const uint n) const {
	    if(n == 0) return empty;
	    else if (n == 1) return this;
	    else return MultiSet!(Repeat!(n, T))(x => prod!(Reapeat!(n,contains))(x));
	}

	MultiSet opBinary(string op : "^")(const MultiSet S) {
		return MultiSet(x => diff(S, x));
	}

	size_t opBinaryRight(string op : "in")(const T t) {
		return contains(t);
	}

	S opCast(S : Set!T)() const {
		return S(x => contains(x) > 0);
	}
}
