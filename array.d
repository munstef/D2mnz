module collections.array;

import core.exception : RangeError;
import std.range.primitives;
import std.traits;

private struct RangeT(A)
{
    /* Workaround for Issue 13629 at https://issues.dlang.org/show_bug.cgi?id=13629
       See also: http://forum.dlang.org/post/vbmwhzvawhnkoxrhbnyb@forum.dlang.org
    */
    private A[1] _outer_;
    private @property ref inout(A) _outer() inout { return _outer_[0]; }

    private size_t _a, _b;

    /* E is different from T when A is more restrictively qualified than T:
       immutable(Array!int) => T == int, E = immutable(int) */
    alias E = typeof(_outer_[0]._data._payload[0]);

    private this(ref A data, size_t a, size_t b)
    {
        _outer_ = data;
        _a = a;
        _b = b;
    }

    @property RangeT save()
    {
        return this;
    }

    @property bool empty() @safe pure nothrow const
    {
        return _a >= _b;
    }

    @property size_t length() @safe pure nothrow const
    {
        return _b - _a;
    }
    alias opDollar = length;

    @property ref inout(E) front() inout
    {
        assert(!empty, "Attempting to access the front of an empty Array");
        return _outer[_a];
    }
    @property ref inout(E) back() inout
    {
        assert(!empty, "Attempting to access the back of an empty Array");
        return _outer[_b - 1];
    }

    void popFront() @safe @nogc pure nothrow
    {
        assert(!empty, "Attempting to popFront an empty Array");
        ++_a;
    }

    void popBack() @safe @nogc pure nothrow
    {
        assert(!empty, "Attempting to popBack an empty Array");
        --_b;
    }

    static if (isMutable!A)
    {
        import std.algorithm.mutation : move;

        E moveFront()
        {
            assert(!empty && _a < _outer.length);
            return move(_outer._data._payload[_a]);
        }

        E moveBack()
        {
            assert(!empty && _b  <= _outer.length);
            return move(_outer._data._payload[_b - 1]);
        }

        E moveAt(size_t i)
        {
            assert(_a + i < _b && _a + i < _outer.length);
            return move(_outer._data._payload[_a + i]);
        }
    }

    ref inout(E) opIndex(size_t i) inout
    {
        assert(_a + i < _b);
        return _outer[_a + i];
    }

    RangeT opSlice()
    {
        return typeof(return)(_outer, _a, _b);
    }

    RangeT opSlice(size_t i, size_t j)
    {
        assert(i <= j && _a + j <= _b);
        return typeof(return)(_outer, _a + i, _a + j);
    }

    RangeT!(const(A)) opSlice() const
    {
        return typeof(return)(_outer, _a, _b);
    }

    RangeT!(const(A)) opSlice(size_t i, size_t j) const
    {
        assert(i <= j && _a + j <= _b);
        return typeof(return)(_outer, _a + i, _a + j);
    }

    static if (isMutable!A)
    {
        void opSliceAssign(E value)
        {
            assert(_b <= _outer.length);
            _outer[_a .. _b] = value;
        }

        void opSliceAssign(E value, size_t i, size_t j)
        {
            assert(_a + j <= _b);
            _outer[_a + i .. _a + j] = value;
        }

        void opSliceUnary(string op)()
        if (op == "++" || op == "--")
        {
            assert(_b <= _outer.length);
            mixin(op~"_outer[_a .. _b];");
        }

        void opSliceUnary(string op)(size_t i, size_t j)
        if (op == "++" || op == "--")
        {
            assert(_a + j <= _b);
            mixin(op~"_outer[_a + i .. _a + j];");
        }

        void opSliceOpAssign(string op)(E value)
        {
            assert(_b <= _outer.length);
            mixin("_outer[_a .. _b] "~op~"= value;");
        }

        void opSliceOpAssign(string op)(E value, size_t i, size_t j)
        {
            assert(_a + j <= _b);
            mixin("_outer[_a + i .. _a + j] "~op~"= value;");
        }
    }
}


/**
 * _Array type with deterministic control of memory. The memory allocated
 * for the array is reclaimed as soon as possible; there is no reliance
 * on the garbage collector. `Array` uses `malloc`, `realloc` and `free`
 * for managing its own memory.
 *
 * This means that pointers to elements of an `Array` will become
 * dangling as soon as the element is removed from the `Array`. On the other hand
 * the memory allocated by an `Array` will be scanned by the GC and
 * GC managed objects referenced from an `Array` will be kept alive.
 *
 * Note:
 *
 * When using `Array` with range-based functions like those in `std.algorithm`,
 * `Array` must be sliced to get a range (for example, use `array[].map!`
* instead of `array.map!`). The container itself is not a range.
*/

struct Array(T)
if (!is(Unqual!T == bool))
{
    import core.memory : pureMalloc, pureRealloc, pureFree;
    private alias malloc = pureMalloc;
    private alias realloc = pureRealloc;
    private alias free = pureFree;
    import core.stdc.string : memcpy, memmove, memset;

    import core.memory : GC;

    import std.exception : enforce;
    import std.typecons : RefCounted, RefCountedAutoInitialize;

    // This structure is not copyable.
    private struct Payload
    {
        size_t _capacity;
        T[] _payload;

        this(T[] p) { _capacity = p.length; _payload = p; }

        // Destructor releases array memory
        ~this()
        {
            // Warning: destroy would destroy also class instances.
            // The hasElaborateDestructor protects us here.
            static if (hasElaborateDestructor!T)
                foreach (ref e; _payload)
                    .destroy(e);

            static if (hasIndirections!T)
                GC.removeRange(_payload.ptr);

            free(_payload.ptr);
        }

        this(this) @disable;

        void opAssign(Payload rhs) @disable;

        @property size_t length() const
        {
            return _payload.length;
        }

        @property void length(size_t newLength)
        {
            import std.algorithm.mutation : initializeAll;

            if (length >= newLength)
            {
                // shorten
                static if (hasElaborateDestructor!T)
                    foreach (ref e; _payload.ptr[newLength .. _payload.length])
                        .destroy(e);

                _payload = _payload.ptr[0 .. newLength];
                return;
            }
            immutable startEmplace = length;
            if (_capacity < newLength)
            {
                // enlarge
                import core.checkedint : mulu;

                bool overflow;
                const nbytes = mulu(newLength, T.sizeof, overflow);
                if (overflow)
                    assert(0);

                static if (hasIndirections!T)
                {
                    auto newPayloadPtr = cast(T*) malloc(nbytes);
                    newPayloadPtr || assert(false, "std.container.Array.length failed to allocate memory.");
                    auto newPayload = newPayloadPtr[0 .. newLength];
                    memcpy(newPayload.ptr, _payload.ptr, startEmplace * T.sizeof);
                    memset(newPayload.ptr + startEmplace, 0,
                            (newLength - startEmplace) * T.sizeof);
                    GC.addRange(newPayload.ptr, nbytes);
                    GC.removeRange(_payload.ptr);
                    free(_payload.ptr);
                    _payload = newPayload;
                }
                else
                {
                    _payload = (cast(T*) realloc(_payload.ptr,
                            nbytes))[0 .. newLength];
                }
                _capacity = newLength;
            }
            else
            {
                _payload = _payload.ptr[0 .. newLength];
            }
            initializeAll(_payload.ptr[startEmplace .. newLength]);
        }

        @property size_t capacity() const
        {
            return _capacity;
        }

        void reserve(size_t elements)
        {
            if (elements <= capacity) return;
            import core.checkedint : mulu;
            bool overflow;
            const sz = mulu(elements, T.sizeof, overflow);
            if (overflow)
                assert(0);
            static if (hasIndirections!T)
            {
                /* Because of the transactional nature of this
                 * relative to the garbage collector, ensure no
                 * threading bugs by using malloc/copy/free rather
                 * than realloc.
                 */
                immutable oldLength = length;

                auto newPayloadPtr = cast(T*) malloc(sz);
                newPayloadPtr || assert(false, "std.container.Array.reserve failed to allocate memory");
                auto newPayload = newPayloadPtr[0 .. oldLength];

                // copy old data over to new array
                memcpy(newPayload.ptr, _payload.ptr, T.sizeof * oldLength);
                // Zero out unused capacity to prevent gc from seeing false pointers
                memset(newPayload.ptr + oldLength,
                        0,
                        (elements - oldLength) * T.sizeof);
                GC.addRange(newPayload.ptr, sz);
                GC.removeRange(_payload.ptr);
                free(_payload.ptr);
                _payload = newPayload;
            }
            else
            {
                // These can't have pointers, so no need to zero unused region
                auto newPayloadPtr = cast(T*) realloc(_payload.ptr, sz);
                newPayloadPtr || assert(false, "std.container.Array.reserve failed to allocate memory");
                auto newPayload = newPayloadPtr[0 .. length];
                _payload = newPayload;
            }
            _capacity = elements;
        }

        // Insert one item
        size_t insertBack(Elem)(Elem elem)
        if (isImplicitlyConvertible!(Elem, T))
        {
            import std.conv : emplace;
            if (_capacity == length)
            {
                reserve(1 + capacity * 3 / 2);
            }
            assert(capacity > length && _payload.ptr);
            emplace(_payload.ptr + _payload.length, elem);
            _payload = _payload.ptr[0 .. _payload.length + 1];
            return 1;
        }

        // Insert a range of items
        size_t insertBack(Range)(Range r)
        if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, T))
        {
            static if (hasLength!Range)
            {
                immutable oldLength = length;
                reserve(oldLength + r.length);
            }
            size_t result;
            foreach (item; r)
            {
                insertBack(item);
                ++result;
            }
            static if (hasLength!Range)
            {
                assert(length == oldLength + r.length);
            }
            return result;
        }
    }
    private alias Data = RefCounted!(Payload, RefCountedAutoInitialize.no);
    private Data _data;

    /**
     * Constructor taking a number of items.
     */
    this(U)(U[] values...)
    if (isImplicitlyConvertible!(U, T))
    {
        import core.checkedint : mulu;
        import std.conv : emplace;
        bool overflow;
        const nbytes = mulu(values.length, T.sizeof, overflow);
        if (overflow) assert(0);
        auto p = cast(T*) malloc(nbytes);
        static if (hasIndirections!T)
        {
            if (p)
                GC.addRange(p, T.sizeof * values.length);
        }

        foreach (i, e; values)
        {
            emplace(p + i, e);
        }
        _data = Data(p[0 .. values.length]);
    }

    /**
     * Constructor taking an $(REF_ALTTEXT input range, isInputRange, std,range,primitives)
     */
    this(Range)(Range r)
    if (isInputRange!Range && isImplicitlyConvertible!(ElementType!Range, T) && !is(Range == T[]))
    {
        insertBack(r);
    }

    /**
     * Comparison for equality.
     */
    bool opEquals(Array rhs) 
    {
        return opEquals(rhs);
    }

    /// ditto
    bool opEquals(ref Array rhs)
    {
        if (empty) return rhs.empty;
        if (rhs.empty) return false;
        return _data._payload == rhs._data._payload;
    }

    /**
     *  Defines the array's primary range, which is a random-access range.
     *
     *  `ConstRange` is a variant with `const` elements.
     *  `ImmutableRange` is a variant with `immutable` elements.
     */
    alias Range = RangeT!Array;

    /// ditto
    alias ConstRange = RangeT!(const Array);

    /// ditto
    alias ImmutableRange = RangeT!(immutable Array);

    /**
     * Duplicates the array. The elements themselves are not transitively
     * duplicated.
     *
     * Complexity: $(BIGOH length).
     */
    @property Array dup()
    {
        if (!_data.refCountedStore.isInitialized) return this;
        return Array(_data._payload);
    }

    /**
     * Returns: `true` if and only if the array has no elements.
     *
     * Complexity: $(BIGOH 1)
     */
    @property bool empty() const
    {
        return !_data.refCountedStore.isInitialized || _data._payload.empty;
    }

    /**
     * Returns: The number of elements in the array.
     *
     * Complexity: $(BIGOH 1).
     */
    @property size_t length() const
    {
        return _data.refCountedStore.isInitialized ? _data._payload.length : 0;
    }

    /// ditto
    size_t opDollar() const
    {
        return length;
    }

    /**
     * Returns: The maximum number of elements the array can store without
     * reallocating memory and invalidating iterators upon insertion.
     *
     * Complexity: $(BIGOH 1)
     */
    @property size_t capacity()
    {
        return _data.refCountedStore.isInitialized ? _data._capacity : 0;
    }

    /**
     * Ensures sufficient capacity to accommodate `e` _elements.
     * If `e < capacity`, this method does nothing.
     *
     * Postcondition: `capacity >= e`
     *
     * Note: If the capacity is increased, one should assume that all
     * iterators to the elements are invalidated.
     *
     * Complexity: at most $(BIGOH length) if `e > capacity`, otherwise $(BIGOH 1).
     */
    void reserve(size_t elements)
    {
        if (!_data.refCountedStore.isInitialized)
        {
            if (!elements) return;
            import core.checkedint : mulu;
            bool overflow;
            const sz = mulu(elements, T.sizeof, overflow);
            if (overflow) assert(0);
            auto p = malloc(sz);
            p || assert(false, "std.container.Array.reserve failed to allocate memory");
            static if (hasIndirections!T)
            {
                GC.addRange(p, sz);
            }
            _data = Data(cast(T[]) p[0 .. 0]);
            _data._capacity = elements;
        }
        else
        {
            _data.reserve(elements);
        }
    }

    /**
     * Returns: A range that iterates over elements of the array in
     * forward order.
     *
     * Complexity: $(BIGOH 1)
     */
    Range opSlice()
    {
        return typeof(return)(this, 0, length);
    }

    ConstRange opSlice() const
    {
        return typeof(return)(this, 0, length);
    }

    ImmutableRange opSlice() immutable
    {
        return typeof(return)(this, 0, length);
    }

    /**
     * Returns: A range that iterates over elements of the array from
     * index `i` up to (excluding) index `j`.
     *
     * Precondition: `i <= j && j <= length`
     *
     * Complexity: $(BIGOH 1)
     */
    Range opSlice(size_t i, size_t j)
    {
        assert(i <= j && j <= length);
        return typeof(return)(this, i, j);
    }

    ConstRange opSlice(size_t i, size_t j) const
    {
        assert(i <= j && j <= length);
        return typeof(return)(this, i, j);
    }

    ImmutableRange opSlice(size_t i, size_t j) immutable
    {
        assert(i <= j && j <= length);
        return typeof(return)(this, i, j);
    }

    /**
     * Returns: The first element of the array.
     *
     * Precondition: `empty == false`
     *
     * Complexity: $(BIGOH 1)
     */
    @property ref inout(T) front() inout
    {
        assert(_data.refCountedStore.isInitialized);
        return _data._payload[0];
    }

    /**
     * Returns: The last element of the array.
     *
     * Precondition: `empty == false`
     *
     * Complexity: $(BIGOH 1)
     */
    @property ref inout(T) back() inout
    {
        assert(_data.refCountedStore.isInitialized);
        return _data._payload[$ - 1];
    }

    /**
     * Returns: The element or a reference to the element at the specified index.
     *
     * Precondition: `i < length`
     *
     * Complexity: $(BIGOH 1)
     */
    ref inout(T) opIndex(size_t i) inout
    {
        assert(_data.refCountedStore.isInitialized);
        return _data._payload[i];
    }

    /**
     * Slicing operators executing the specified operation on the entire slice.
     *
     * Precondition: `i < j && j < length`
     *
     * Complexity: $(BIGOH slice.length)
     */
    void opSliceAssign(T value)
    {
        if (!_data.refCountedStore.isInitialized) return;
        _data._payload[] = value;
    }

    /// ditto
    void opSliceAssign(T value, size_t i, size_t j)
    {
        auto slice = _data.refCountedStore.isInitialized ?
            _data._payload :
            T[].init;
        slice[i .. j] = value;
    }

    /// ditto
    void opSliceUnary(string op)()
    if (op == "++" || op == "--")
    {
        if (!_data.refCountedStore.isInitialized) return;
        mixin(op~"_data._payload[];");
    }

    /// ditto
    void opSliceUnary(string op)(size_t i, size_t j)
    if (op == "++" || op == "--")
    {
        auto slice = _data.refCountedStore.isInitialized ? _data._payload : T[].init;
        mixin(op~"slice[i .. j];");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value)
    {
        if (!_data.refCountedStore.isInitialized) return;
        mixin("_data._payload[] "~op~"= value;");
    }

    /// ditto
    void opSliceOpAssign(string op)(T value, size_t i, size_t j)
    {
        auto slice = _data.refCountedStore.isInitialized ? _data._payload : T[].init;
        mixin("slice[i .. j] "~op~"= value;");
    }

    private enum hasSliceWithLength(T) = is(typeof({ T t = T.init; t[].length; }));

    /**
     * Returns: A new array which is a concatenation of `this` and its argument.
     *
     * Complexity:
     * $(BIGOH length + m), where `m` is the number of elements in `stuff`.
     */
    Array opBinary(string op, Stuff)(Stuff stuff)
    if (op == "~")
    {
        Array result;

        static if (hasLength!Stuff || isNarrowString!Stuff)
            result.reserve(length + stuff.length);
        else static if (hasSliceWithLength!Stuff)
            result.reserve(length + stuff[].length);
        else static if (isImplicitlyConvertible!(Stuff, T))
            result.reserve(length + 1);

        result.insertBack(this[]);
        result ~= stuff;
        return result;
    }

    /**
     * Forwards to `insertBack`.
     */
    void opOpAssign(string op, Stuff)(auto ref Stuff stuff)
    if (op == "~")
    {
        static if (is(typeof(stuff[])) && isImplicitlyConvertible!(typeof(stuff[0]), T))
        {
            insertBack(stuff[]);
        }
        else
        {
            insertBack(stuff);
        }
    }

    /**
     * Removes all the elements from the array and releases allocated memory.
     *
     * Postcondition: `empty == true && capacity == 0`
     *
     * Complexity: $(BIGOH length)
     */
    void clear()
    {
        _data = Data.init;
    }

    /**
     * Sets the number of elements in the array to `newLength`. If `newLength`
     * is greater than `length`, the new elements are added to the end of the
     * array and initialized with `T.init`.
     *
     * Complexity:
     * Guaranteed $(BIGOH abs(length - newLength)) if `capacity >= newLength`.
     * If `capacity < newLength` the worst case is $(BIGOH newLength).
     *
     * Postcondition: `length == newLength`
     */
    @property void length(size_t newLength)
    {
        _data.refCountedStore.ensureInitialized();
        _data.length = newLength;
    }

    /**
     * Removes the last element from the array and returns it.
     * Both stable and non-stable versions behave the same and guarantee
     * that ranges iterating over the array are never invalidated.
     *
     * Precondition: `empty == false`
     *
     * Returns: The element removed.
     *
     * Complexity: $(BIGOH 1).
     *
     * Throws: `Exception` if the array is empty.
     */
    T removeAny()
    {
        auto result = back;
        removeBack();
        return result;
    }

    /// ditto
    alias stableRemoveAny = removeAny;

    /**
     * Inserts the specified elements at the back of the array. `stuff` can be
     * a value convertible to `T` or a range of objects convertible to `T`.
     *
     * Returns: The number of elements inserted.
     *
     * Complexity:
     * $(BIGOH length + m) if reallocation takes place, otherwise $(BIGOH m),
     * where `m` is the number of elements in `stuff`.
     */
    size_t insertBack(Stuff)(Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T) ||
            isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        _data.refCountedStore.ensureInitialized();
        return _data.insertBack(stuff);
    }

    /// ditto
    alias insert = insertBack;

    /**
     * Removes the value from the back of the array. Both stable and non-stable
     * versions behave the same and guarantee that ranges iterating over the
     * array are never invalidated.
     *
     * Precondition: `empty == false`
     *
     * Complexity: $(BIGOH 1).
     *
     * Throws: `Exception` if the array is empty.
     */
    void removeBack()
    {
        enforce(!empty);
        static if (hasElaborateDestructor!T)
            .destroy(_data._payload[$ - 1]);

        _data._payload = _data._payload[0 .. $ - 1];
    }

    /// ditto
    alias stableRemoveBack = removeBack;

    /**
     * Removes `howMany` values from the back of the array.
     * Unlike the unparameterized versions above, these functions
     * do not throw if they could not remove `howMany` elements. Instead,
     * if `howMany > n`, all elements are removed. The returned value is
     * the effective number of elements removed. Both stable and non-stable
     * versions behave the same and guarantee that ranges iterating over
     * the array are never invalidated.
     *
     * Returns: The number of elements removed.
     *
     * Complexity: $(BIGOH howMany).
     */
    size_t removeBack(size_t howMany)
    {
        if (howMany > length) howMany = length;
        static if (hasElaborateDestructor!T)
            foreach (ref e; _data._payload[$ - howMany .. $])
                .destroy(e);

        _data._payload = _data._payload[0 .. $ - howMany];
        return howMany;
    }

    /// ditto
    alias stableRemoveBack = removeBack;

    /**
     * Inserts `stuff` before, after, or instead range `r`, which must
     * be a valid range previously extracted from this array. `stuff`
     * can be a value convertible to `T` or a range of objects convertible
     * to `T`. Both stable and non-stable version behave the same and
     * guarantee that ranges iterating over the array are never invalidated.
     *
     * Returns: The number of values inserted.
     *
     * Complexity: $(BIGOH length + m), where `m` is the length of `stuff`.
     *
     * Throws: `Exception` if `r` is not a range extracted from this array.
     */
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        import std.conv : emplace;
        enforce(r._outer._data is _data && r._a <= length);
        reserve(length + 1);
        assert(_data.refCountedStore.isInitialized);
        // Move elements over by one slot
        memmove(_data._payload.ptr + r._a + 1,
                _data._payload.ptr + r._a,
                T.sizeof * (length - r._a));
        emplace(_data._payload.ptr + r._a, stuff);
        _data._payload = _data._payload.ptr[0 .. _data._payload.length + 1];
        return 1;
    }

    /// ditto
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        import std.conv : emplace;
        enforce(r._outer._data is _data && r._a <= length);
        static if (isForwardRange!Stuff)
        {
            // Can find the length in advance
            auto extra = walkLength(stuff);
            if (!extra) return 0;
            reserve(length + extra);
            assert(_data.refCountedStore.isInitialized);
            // Move elements over by extra slots
            memmove(_data._payload.ptr + r._a + extra,
                    _data._payload.ptr + r._a,
                    T.sizeof * (length - r._a));
            foreach (p; _data._payload.ptr + r._a ..
                    _data._payload.ptr + r._a + extra)
            {
                emplace(p, stuff.front);
                stuff.popFront();
            }
            _data._payload =
                _data._payload.ptr[0 .. _data._payload.length + extra];
            return extra;
        }
        else
        {
            import std.algorithm.mutation : bringToFront;
            enforce(_data);
            immutable offset = r._a;
            enforce(offset <= length);
            auto result = insertBack(stuff);
            bringToFront(this[offset .. length - result],
                    this[length - result .. length]);
            return result;
        }
    }

    /// ditto
    alias stableInsertBefore = insertBefore;

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        import std.algorithm.mutation : bringToFront;
        enforce(r._outer._data is _data);
        // TODO: optimize
        immutable offset = r._b;
        enforce(offset <= length);
        auto result = insertBack(stuff);
        bringToFront(this[offset .. length - result],
                this[length - result .. length]);
        return result;
    }

    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isInputRange!Stuff && isImplicitlyConvertible!(ElementType!Stuff, T))
    {
        enforce(r._outer._data is _data);
        size_t result;
        for (; !stuff.empty; stuff.popFront())
        {
            if (r.empty)
            {
                // insert the rest
                return result + insertBefore(r, stuff);
            }
            r.front = stuff.front;
            r.popFront();
            ++result;
        }
        // Remove remaining stuff in r
        linearRemove(r);
        return result;
    }

    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
    if (isImplicitlyConvertible!(Stuff, T))
    {
        enforce(r._outer._data is _data);
        if (r.empty)
        {
            insertBefore(r, stuff);
        }
        else
        {
            r.front = stuff;
            r.popFront();
            linearRemove(r);
        }
        return 1;
    }

    /**
     * Removes all elements belonging to `r`, which must be a range
     * obtained originally from this array.
     *
     * Returns: A range spanning the remaining elements in the array that
     * initially were right after `r`.
     *
     * Complexity: $(BIGOH length)
     *
     * Throws: `Exception` if `r` is not a valid range extracted from this array.
     */
    Range linearRemove(Range r)
    {
        import std.algorithm.mutation : copy;

        enforce(r._outer._data is _data);
        enforce(_data.refCountedStore.isInitialized);
        enforce(r._a <= r._b && r._b <= length);
        immutable offset1 = r._a;
        immutable offset2 = r._b;
        immutable tailLength = length - offset2;
        // Use copy here, not a[] = b[] because the ranges may overlap
        copy(this[offset2 .. length], this[offset1 .. offset1 + tailLength]);
        length = offset1 + tailLength;
        return this[length - tailLength .. length];
    }
}


struct Array(T)
if (is(Unqual!T == bool))
{
    import std.exception : enforce;
    import std.typecons : RefCounted, RefCountedAutoInitialize;

    static immutable uint bitsPerWord = size_t.sizeof * 8;
    private static struct Data
    {
        Array!size_t.Payload _backend;
        size_t _length;
    }
    private RefCounted!(Data, RefCountedAutoInitialize.no) _store;

    private @property ref size_t[] data()
    {
        assert(_store.refCountedStore.isInitialized);
        return _store._backend._payload;
    }

    /**
	* Defines the array's primary range.
	*/
    struct Range
    {
        private Array _outer;
        private size_t _a, _b;
        /// Range primitives
        @property Range save()
        {
            version (bug4437)
            {
                return this;
            }
            else
            {
                auto copy = this;
                return copy;
            }
        }
        /// Ditto
        @property bool empty()
        {
            return _a >= _b || _outer.length < _b;
        }
        /// Ditto
        @property T front()
        {
            enforce(!empty, "Attempting to access the front of an empty Array");
            return _outer[_a];
        }
        /// Ditto
        @property void front(bool value)
        {
            enforce(!empty, "Attempting to set the front of an empty Array");
            _outer[_a] = value;
        }
        /// Ditto
        T moveFront()
        {
            enforce(!empty, "Attempting to move the front of an empty Array");
            return _outer.moveAt(_a);
        }
        /// Ditto
        void popFront()
        {
            enforce(!empty, "Attempting to popFront an empty Array");
            ++_a;
        }
        /// Ditto
        @property T back()
        {
            enforce(!empty, "Attempting to access the back of an empty Array");
            return _outer[_b - 1];
        }
        /// Ditto
        @property void back(bool value)
        {
            enforce(!empty, "Attempting to set the back of an empty Array");
            _outer[_b - 1] = value;
        }
        /// Ditto
        T moveBack()
        {
            enforce(!empty, "Attempting to move the back of an empty Array");
            return _outer.moveAt(_b - 1);
        }
        /// Ditto
        void popBack()
        {
            enforce(!empty, "Attempting to popBack an empty Array");
            --_b;
        }
        /// Ditto
        T opIndex(size_t i)
        {
            return _outer[_a + i];
        }
        /// Ditto
        void opIndexAssign(T value, size_t i)
        {
            _outer[_a + i] = value;
        }
        /// Ditto
        T moveAt(size_t i)
        {
            return _outer.moveAt(_a + i);
        }
        /// Ditto
        @property size_t length() const
        {
            assert(_a <= _b);
            return _b - _a;
        }
        alias opDollar = length;
        /// ditto
        Range opSlice(size_t low, size_t high)
        {
            // Note: indexes start at 0, which is equivalent to _a
            assert(
				   low <= high && high <= (_b - _a),
				   "Using out of bounds indexes on an Array"
				   );
            return Range(_outer, _a + low, _a + high);
        }
    }

    /**
	* Property returning `true` if and only if the array has
	* no elements.
	*
	* Complexity: $(BIGOH 1)
	*/
    @property bool empty()
    {
        return !length;
    }

    /**
	* Returns: A duplicate of the array.
	*
	* Complexity: $(BIGOH length).
	*/
    @property Array dup()
    {
        Array result;
        result.insertBack(this[]);
        return result;
    }

    /**
	* Returns the number of elements in the array.
	*
	* Complexity: $(BIGOH 1).
	*/
    @property size_t length() const
    {
        return _store.refCountedStore.isInitialized ? _store._length : 0;
    }
    size_t opDollar() const
    {
        return length;
    }

    /**
	* Returns: The maximum number of elements the array can store without
	* reallocating memory and invalidating iterators upon insertion.
	*
	* Complexity: $(BIGOH 1).
	*/
    @property size_t capacity()
    {
        return _store.refCountedStore.isInitialized
            ? cast(size_t) bitsPerWord * _store._backend.capacity
				: 0;
    }

    /**
	* Ensures sufficient capacity to accommodate `e` _elements.
	* If `e < capacity`, this method does nothing.
	*
	* Postcondition: `capacity >= e`
	*
	* Note: If the capacity is increased, one should assume that all
	* iterators to the elements are invalidated.
	*
	* Complexity: at most $(BIGOH length) if `e > capacity`, otherwise $(BIGOH 1).
	*/
    void reserve(size_t e)
    {
        import std.conv : to;
        _store.refCountedStore.ensureInitialized();
        _store._backend.reserve(to!size_t((e + bitsPerWord - 1) / bitsPerWord));
    }

    /**
	* Returns: A range that iterates over all elements of the array in forward order.
	*
	* Complexity: $(BIGOH 1)
	*/
    Range opSlice()
    {
        return Range(this, 0, length);
    }


    /**
	* Returns: A range that iterates the array between two specified positions.
	*
	* Complexity: $(BIGOH 1)
	*/
    Range opSlice(size_t a, size_t b)
    {
        enforce(a <= b && b <= length);
        return Range(this, a, b);
    }

    /**
	* Returns: The first element of the array.
	*
	* Precondition: `empty == false`
	*
	* Complexity: $(BIGOH 1)
	*
	* Throws: `Exception` if the array is empty.
	*/
    @property bool front()
    {
        enforce(!empty);
        return data.ptr[0] & 1;
    }

    /// Ditto
    @property void front(bool value)
    {
        enforce(!empty);
        if (value) data.ptr[0] |= 1;
        else data.ptr[0] &= ~cast(size_t) 1;
    }

    /**
	* Returns: The last element of the array.
	*
	* Precondition: `empty == false`
	*
	* Complexity: $(BIGOH 1)
	*
	* Throws: `Exception` if the array is empty.
	*/
    @property bool back()
    {
        enforce(!empty);
        return cast(bool)(data.back & (cast(size_t) 1 << ((_store._length - 1) % bitsPerWord)));
    }

    /// Ditto
    @property void back(bool value)
    {
        enforce(!empty);
        if (value)
        {
            data.back |= (cast(size_t) 1 << ((_store._length - 1) % bitsPerWord));
        }
        else
        {
            data.back &=
                ~(cast(size_t) 1 << ((_store._length - 1) % bitsPerWord));
        }
    }

    /**
	* Indexing operators yielding or modifyng the value at the specified index.
	*
	* Precondition: `i < length`
	*
	* Complexity: $(BIGOH 1)
	*/
    bool opIndex(size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        return cast(bool)(data.ptr[div] & (cast(size_t) 1 << rem));
    }

    /// ditto
    void opIndexAssign(bool value, size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        if (value) data.ptr[div] |= (cast(size_t) 1 << rem);
        else data.ptr[div] &= ~(cast(size_t) 1 << rem);
    }

    /// ditto
    void opIndexOpAssign(string op)(bool value, size_t i)
    {
        auto div = cast(size_t) (i / bitsPerWord);
        auto rem = i % bitsPerWord;
        enforce(div < data.length);
        auto oldValue = cast(bool) (data.ptr[div] & (cast(size_t) 1 << rem));
        // Do the deed
        auto newValue = mixin("oldValue "~op~" value");
        // Write back the value
        if (newValue != oldValue)
        {
            if (newValue) data.ptr[div] |= (cast(size_t) 1 << rem);
            else data.ptr[div] &= ~(cast(size_t) 1 << rem);
        }
    }

    /// Ditto
    T moveAt(size_t i)
    {
        return this[i];
    }

    /**
	* Returns: A new array which is a concatenation of `this` and its argument.
	*
	* Complexity:
	* $(BIGOH length + m), where `m` is the number of elements in `stuff`.
	*/
    Array!bool opBinary(string op, Stuff)(Stuff rhs)
		if (op == "~")
		{
			Array!bool result;

			static if (hasLength!Stuff)
				result.reserve(length + rhs.length);
			else static if (is(typeof(rhs[])) && hasLength!(typeof(rhs[])))
				result.reserve(length + rhs[].length);
			else static if (isImplicitlyConvertible!(Stuff, bool))
				result.reserve(length + 1);

			result.insertBack(this[]);
			result ~= rhs;
			return result;
		}

    /**
	* Forwards to `insertBack`.
	*/
    Array!bool opOpAssign(string op, Stuff)(Stuff stuff)
		if (op == "~")
		{
			static if (is(typeof(stuff[]))) insertBack(stuff[]);
			else insertBack(stuff);
			return this;
		}

    /**
	* Removes all the elements from the array and releases allocated memory.
	*
	* Postcondition: `empty == true && capacity == 0`
	*
	* Complexity: $(BIGOH length)
	*/
    void clear()
    {
        this = Array();
    }

    /**
	* Sets the number of elements in the array to `newLength`. If `newLength`
	* is greater than `length`, the new elements are added to the end of the
	* array and initialized with `false`.
	*
	* Complexity:
	* Guaranteed $(BIGOH abs(length - newLength)) if `capacity >= newLength`.
	* If `capacity < newLength` the worst case is $(BIGOH newLength).
	*
	* Postcondition: `length == newLength`
	*/
    @property void length(size_t newLength)
    {
        import std.conv : to;
        _store.refCountedStore.ensureInitialized();
        auto newDataLength =
            to!size_t((newLength + bitsPerWord - 1) / bitsPerWord);
        _store._backend.length = newDataLength;
        _store._length = newLength;
    }

    /**
	* Removes the last element from the array and returns it.
	* Both stable and non-stable versions behave the same and guarantee
	* that ranges iterating over the array are never invalidated.
	*
	* Precondition: `empty == false`
	*
	* Returns: The element removed.
	*
	* Complexity: $(BIGOH 1).
	*
	* Throws: `Exception` if the array is empty.
	*/
    T removeAny()
    {
        auto result = back;
        removeBack();
        return result;
    }

    /// ditto
    alias stableRemoveAny = removeAny;

    /**
	* Inserts the specified elements at the back of the array. `stuff` can be
	* a value convertible to `bool` or a range of objects convertible to `bool`.
	*
	* Returns: The number of elements inserted.
	*
	* Complexity:
	* $(BIGOH length + m) if reallocation takes place, otherwise $(BIGOH m),
	* where `m` is the number of elements in `stuff`.
	*/
    size_t insertBack(Stuff)(Stuff stuff)
		if (is(Stuff : bool))
		{
			_store.refCountedStore.ensureInitialized();
			auto rem = _store._length % bitsPerWord;
			if (rem)
			{
				// Fits within the current array
				if (stuff)
				{
					data[$ - 1] |= (cast(size_t) 1 << rem);
				}
				else
				{
					data[$ - 1] &= ~(cast(size_t) 1 << rem);
				}
			}
			else
			{
				// Need to add more data
				_store._backend.insertBack(stuff);
			}
			++_store._length;
			return 1;
		}

    /// ditto
    size_t insertBack(Stuff)(Stuff stuff)
		if (isInputRange!Stuff && is(ElementType!Stuff : bool))
		{
			static if (!hasLength!Stuff) size_t result;
			for (; !stuff.empty; stuff.popFront())
			{
				insertBack(stuff.front);
				static if (!hasLength!Stuff) ++result;
			}
			static if (!hasLength!Stuff) return result;
			else return stuff.length;
		}

    /// ditto
    alias stableInsertBack = insertBack;

    /// ditto
    alias insert = insertBack;

    /// ditto
    alias stableInsert = insertBack;

    /// ditto
    alias linearInsert = insertBack;

    /// ditto
    alias stableLinearInsert = insertBack;

    /**
	* Removes the value from the back of the array. Both stable and non-stable
	* versions behave the same and guarantee that ranges iterating over the
	* array are never invalidated.
	*
	* Precondition: `empty == false`
	*
	* Complexity: $(BIGOH 1).
	*
	* Throws: `Exception` if the array is empty.
	*/
    void removeBack()
    {
        enforce(_store._length);
        if (_store._length % bitsPerWord)
        {
            // Cool, just decrease the length
            --_store._length;
        }
        else
        {
            // Reduce the allocated space
            --_store._length;
            _store._backend.length = _store._backend.length - 1;
        }
    }

    /// ditto
    alias stableRemoveBack = removeBack;

    /**
	* Removes `howMany` values from the back of the array. Unlike the
	* unparameterized versions above, these functions do not throw if
	* they could not remove `howMany` elements. Instead, if `howMany > n`,
	* all elements are removed. The returned value is the effective number
	* of elements removed. Both stable and non-stable versions behave the same
	* and guarantee that ranges iterating over the array are never invalidated.
	*
	* Returns: The number of elements removed.
	*
	* Complexity: $(BIGOH howMany).
	*/
    size_t removeBack(size_t howMany)
    {
        if (howMany >= length)
        {
            howMany = length;
            clear();
        }
        else
        {
            length = length - howMany;
        }
        return howMany;
    }

    /// ditto
    alias stableRemoveBack = removeBack;

    /**
	* Inserts `stuff` before, after, or instead range `r`, which must
	* be a valid range previously extracted from this array. `stuff`
	* can be a value convertible to `bool` or a range of objects convertible
	* to `bool`. Both stable and non-stable version behave the same and
	* guarantee that ranges iterating over the array are never invalidated.
	*
	* Returns: The number of values inserted.
	*
	* Complexity: $(BIGOH length + m), where `m` is the length of `stuff`.
	*/
    size_t insertBefore(Stuff)(Range r, Stuff stuff)
    {
        import std.algorithm.mutation : bringToFront;
        // TODO: make this faster, it moves one bit at a time
        immutable inserted = stableInsertBack(stuff);
        immutable tailLength = length - inserted;
        bringToFront(
					 this[r._a .. tailLength],
					 this[tailLength .. length]);
        return inserted;
    }

    /// ditto
    alias stableInsertBefore = insertBefore;

    /// ditto
    size_t insertAfter(Stuff)(Range r, Stuff stuff)
    {
        import std.algorithm.mutation : bringToFront;
        // TODO: make this faster, it moves one bit at a time
        immutable inserted = stableInsertBack(stuff);
        immutable tailLength = length - inserted;
        bringToFront(
					 this[r._b .. tailLength],
					 this[tailLength .. length]);
        return inserted;
    }

    /// ditto
    alias stableInsertAfter = insertAfter;

    /// ditto
    size_t replace(Stuff)(Range r, Stuff stuff)
		if (is(Stuff : bool))
		{
			if (!r.empty)
			{
				// There is room
				r.front = stuff;
				r.popFront();
				linearRemove(r);
			}
			else
			{
				// No room, must insert
				insertBefore(r, stuff);
			}
			return 1;
		}

    /// ditto
    alias stableReplace = replace;

    /**
	* Removes all elements belonging to `r`, which must be a range
	* obtained originally from this array.
	*
	* Returns: A range spanning the remaining elements in the array that
	* initially were right after `r`.
	*
	* Complexity: $(BIGOH length)
	*/
    Range linearRemove(Range r)
    {
        import std.algorithm.mutation : copy;
        copy(this[r._b .. length], this[r._a .. length]);
        length = length - r.length;
        return this[r._a .. length];
    }
}
