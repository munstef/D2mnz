module collections.array2d;

struct Array2D(E, size_t height, size_t width) if(m && n) {

	union {
		E[height][width] array;
		E[height * width] _array;
	}

	
	this(E[] elements...) {
		foreach(i, e; elements) _array[i] = e;
	}

	this(this) {
		_array = _array.dup;
	}

	this(const Array2D arr){
		array = arr.dup;
	}

	size_t[2] opSlice(size_t dim)(size_t i, size_t j) if(dim < 2) {
		static if (dim) enforce(i <= width && j <= width, "out of range");
		else enforce(i <= heigth && j <= heigth, "out of range");
		return [i, j];
	}

	size_t opDollar(size_t dim)() const @property if(dim < 2) {
		return (dim) ? width : heigth;
	}

	auto opIndex(size_t[2] i, size_t[2] j) const {
		Array2D!(E, i[1] - i[0], j[1] - j[0]) res; 
		foreach(ii; i[0] .. i[1]) res.array[ii - i[0]][0 .. res.width] = array[ii][j[0] .. j[1]];
		return res;
	}

	auto opIndex(size_t[2] i, size_t j) const {
		enforce(j < heigth, "out of range");
		return opIndex(i, [j, j + 1]);
	}

	auto opIndex(size_t i, size_t[2] j) const {
		enforce(i < width, "out of range");
		return opIndex([i, i + 1], j);
	}

	E opIndex(size_t i, size_t j) const {
		enforce(i < width && j < heigth, "out of range");
		return array[i][j];
	}

	ref E opIndexAssign(const E value, size_t i, size_t j){
		enforce(i < width && j < heigth, "out of range");
		return array[i][j] = value;
	}

	ref Array2D opIndexAssign(const E value, size_t[2] i, size_t[2] j) {
		foreach(ii; i[0] .. i[1]) foreach(jj; j[0] .. j[1]) array[ii][jj] = value;
		return this;
	}

	ref Array2D opIndexAssign(const E value, size_t i, size_t[2] j) {
		enforce(i < width, "out of range");
		array[i][j[0] .. j[1]] = value;
		return this;
	}

	ref Array2D opIndexAssign(const E value, size_t[2] i, size_t j) {
		enforce(j < heigth, "out of range");
		foreach(ii; i[0] .. i[1])  array[ii][j] = value;
		return this;
	}

	ref Array2D opIndexAssign(const E value) {
		array[][] = value;
		return this;
	}	

	ref E opIndexOpAssign(string op)(const E value, size_t i, size_t j) {
		enforce(i < width && j < heigth, "out of range");
		return array[i][j].opOpAssign!op(value);
	}

	ref Array2D opIndexOpAssign(string op)(const E value, size_t[2] i, size_t[2] j) {
		foreach(ii; i[0] .. i[1]) foreach(jj; j[0] .. j[1]) array[ii][jj].opOpAssign!op(value);
		return this;
	}

	ref Array2D opIndexOpAssign(string op)(const E value, size_t i, size_t[2] j) {
		enforce(i < width, "out of range");
		array[i][j[0] .. j[1]].opOpAssign!op(value);
		return this;
	}

	ref Array2D opIndexOpAssign(string op)(const E value, size_t[2] i, size_t j) {
		enforce(j < heigth, "out of range");
		foreach(ii; i[0] .. i[1]) array[ii][j].opOpAssign!op(value);
		return this;
	}

	ref Array2D opIndexOpAssign(string op)(const E value) {
		foreach(i; 0 .. width) foreach(j; 0 .. height) array[i][j].opOpAssign!op(value);
		return this;
	}

	ref Array2D opIndexAssign(const Array2D arr, size_t i, size_t j) {
		enforce(i + arr.width < width && j + arr.heigth < heigth, "out of range");
		foreach(ii; 0 .. arr.width) foreach(jj; 0 .. arr.height) array[i + ii][j + jj].opOpAssign(arr.array[ii][jj]);
		return this;
	}

	ref Array2D opIndexAssign(const Array2D arr, size_t[2] i, size_t[2] j) {
		enforce(i[0] + arr.width < width && j[0] + arr.heigth < heigth && i[1] + arr.width <= width && j[1] + arr.heigth <= heigth, "out of range");
		foreach(ii; i[0] .. i[1]) foreach(jj; j[0] .. j[1]) array[ii][jj] = arr.array[ii - i[0]][jj - j[0]];
		return this;
	}

	ref Array2D opIndexAssign(const Array2D arr, size_t i, size_t[2] j) {
		enforce(i < width && j[0] + arr.heigth < heigth && j[1] + arr.heigth <= heigth, "out of range");
		foreach(jj; j[0] .. j[1]) array[i][jj] = arr.array[0][jj - j[0]];
		return this;
	}

	ref Array2D opIndexAssign(const Array2D arr, size_t[2] i, size_t j) {
		enforce(i[0] + arr.width < width && i[1] + arr.width <= width && j < heigth, "out of range");
		foreach(ii; i[0] .. i[1]) array[ii][j] = arr.array[ii - i[0]][0];
		return this;
	}

	ref Array2D opIndexAssign(const Array2D arr) {
		enforce(arr.width <= width && arr.heigth <= heigth, "out of range");
		foreach(i; 0 .. arr.width) foreach(j; 0 .. arr.heigth) array[i][j] = arr.array[i][j];
		return this;
	}

	T opIndexUnary(string op, T)(size_t i, size_t j) const if(is(T == typeof(E.init.opUnary!op()))) {
		enforce(i < width && j < heigth, "out of range");
		return array[i][j].opUnary!op();
	}

	Array2D!T opIndexUnary(string op, T)(size_t[2] i, size_t[2] j) const if(is(T == typeof(E.init.opUnary!op()))) {
		Array2D!T Res = Array2D!T(i[1] - i[0], j[1] - j[0]);
		foreach(ii; 0 .. Res.width) foreach(jj; 0 .. Res.height) Res.array[ii][jj] = array[i[0] + ii][j[0] + jj].opUnary!op();
		return Res;
	}

	Array2D!T opIndexUnary(string op, T)(size_t i, size_t[2] j) const if(is(T == typeof(E.init.opUnary!op()))) {
		enforce(i < width, "out of range");
		Array2D!T Res = Array2D!T(1, j[1] - j[0]);
		foreach(jj; 0 .. Res.height) Res.array[0][jj] = array[i][j[0] + jj].opUnary!op();
		return Res;
	}

	Array2D!T opIndexUnary(string op, T)(size_t[2] i, size_t j) const if(is(T == typeof(E.init.opUnary!op()))) {
		enforce(j < heigth, "out of range");
		Array2D!T Res = Array2D!T(i[1] - i[0], 1);
		foreach(ii; 0 .. Res.width) Res.array[ii][j] = array[ii - i[0]][j].opUnary!op();
		return Res;
	}

	Array2D!T opIndexUnary(string op, T)() const if(is(T == typeof(E.init.opUnary!op()))) {
		Array2D!T Res = Array2D!T(width, heigth);
		foreach(ii; 0 .. width) foreach(jj; 0 .. heigth) Res.array[ii][jj] = array[ii - i[0]][jj - j[0]].opUnary!op();
		return Res;
	}

	ref E opIndexUnary(string op)(size_t i, size_t j) if(op == "++" || op =="--") {
		return array[i][j].opUnary!op();
	}

	ref Array2D opIndexUnary(string op)(size_t[2] i, siza_t j) if(op == "++" || op == "--") {
		return opIndexUnary!op(i, [j, j + 1]);
	}

	ref Array2D opIndexUnary(string op)(size_t i, siza_t[2] j) if(op == "++" || op == "--") {
		return opIndexUnary!op([i, i + 1], j);
	}

	ref Array2D opIndexUnary(string op)(size_t[2] i, size_t[2] j) if(op == "++" || op == "--") {
		foreach(ii; i[0] .. j[0]) foreach(jj; j[0] .. j[1]) array[ii][jj].opUnary!op();
		return this;
	}

	int opApply(scope int delegate(ref E) dg) {
		int result = 0;
		foreach (i; array) foreach(j; i) {
			result = dg(j);
			if (result) break;
		}
		return result;
	}

	int opApply(scope int delegate(ref E , size_t, size_t) dg) {	
		int result = 0;
		foreach (i, _i; array) foreach(j, _j; i) {
			result = dg(j, _i, _j);
			if (result) break;
		}
		return result;
	}

	int opApplyReverse(scope int delegate(ref E) dg) {
		int result = 0;
		foreach_reverse (i; array) foreach_reverse(j; i) {
			result = dg(j);
			if (result) break;
		}
		return result;
	}

	int opApplyReverse(scope int delegate(ref E, size_t, size_t) dg) {	
		int result = 0;
		foreach_reverse (i, _i; array) foreach_reverse(j, _j; i) {
			result = dg(j, _i, _j);
			if (result) break;
		}
		return result;
	}

	struct Range {

		ref Array2D array;

		size_t i, j;

		this(ref Array2D arr, size_t i, size_t j) {
			this.i = i; this.j = j; arr = array;
		}

		ref E front() {
			return arr.array[i][j];
		}

		void popFront() {
			++i;
			if (i > arr.width) {i = 0; ++j;}
		}

		bool empty() const {
			return j >= heigth;
		}

	}

	Array2D!E concatWidth(const array2D!E[] arr...) {
		size_t wt = width;
		if(arr.length == 0) return this;
		foreach(a; arr) {
			enforce(a.heigth == heigth, "concate on with with two incompatible arrays");
			wt += a.width;
		}
		Array2D!T res = Array2D!T(heigth, wt);
		res[0, 0] = this; size_t w = width;
		foreach(a; arr) {
			res[0, w] = a; 
			w += a.width;
		}
		return res;
	}

	alias concatHorizontal = concatWidth;

	Array2D!E concatHeigth(const array2D!E[] arr...) {
		if(arr.length == 0) return this;
		size_t ht = heigth;
		foreach(a; arr) {
			enforce(a.width == width, "concate on with with two incompatible arrays");
			ht += a.heigth;
		}
		Array2D!T res = Array2D!T(heigth, wt);
		res[0, 0] = this; size_t h = heigth;
		foreach(a; arr) {
			res[h, 0] = a; 
			h += a.heigth;
		}
		return res;
	}

	alias concatVertical = concatHeigth;

	Array2D!E VectorColumn(size_t m)() const @property {
		enforce(m < width, "index out of range");
		Array2D!E res = Array2D!E(height, 1);
		foreach(a, i; array) res.array[i][m] = a[m];
		return res;
	}

	Array2D!E VectorRow(size_t m)() const @property {
		enforce(m < heigth, "index out of range");
		Array2D!E res = Array2D!E(1, width);
		res.array[0] = array[m];
		return res;
	}

	Range range(size_t i = 0, size_t j = 0) @property {
		return Range(this, i, j);
	}

	size_t size() const @property {
		return width * heigth;
	}

	Array2D!T transpose() const @property {
		Array2D!T res = Array2D!T(width, heigth);
		foreach(v, i, j; this) res.array[j][i] = v;
		return res;
	}

	M opCast(M : Matrix!(E, height, width))() const {
		M m;
		m.coeffs = array.dup;
	}

}
