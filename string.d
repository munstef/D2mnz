module collections.string;

struct String(T){

	T[] _;

	mixin Proxy!_;

	this(T[] arg...) { _ = arg.dup; }
	this(const T t) { _ = [t]; }
	static if(is_comparable!T) {
		int opCmp(const T t) const {
			if (!_.length) return -1;
			return _[0] < t ? -1 : _[0] > t ? 1 : _.length > 1;
		}
		int opCmp(const String s) const {
			t = min(_length, s._.length);
			for(size_t i = 0; i < t; ++i) if (_[i] < s._[i]) return -1; else if (_[i] > s._[i]) return 1;
			return _.length - s._.length;
		}
	}

    bool isEqual(const T t) const { return s._.length == 1 && s._[0] == t;}
    bool isEqual(const String s) const {
        if (_.length == s._.length) {
					foreach(i, v; _) if (v != s._[i]) return false;
				} else return false;
        return true;
    }
}
