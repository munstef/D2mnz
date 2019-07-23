module collections.queue;

struct Queue(T) {
private:

	T[] array;
	size_t _length, _head, _tail;

public:

	this(this) { array = array.dup;}

	this(const Queue Q) {
	    array = Q.array.dup;
	    _length = Q._tail;
	    _head = Q._head;
	    _length = Q._length;
    }

	this(const T[] arg...) {
	    array = arg.dup;
	    _length = array.length;
	    _head = array.length - 1;
	    _tail = 0;
    }

	size_t length() const @property { return _length;}

	bool empty() const { return !_length;}

	private bool full() const { return _length == array.length;}

	T head() const @property
    in { enforce(!empty, "Queue is empty");}
	do {
		return array[_head];
	}

	alias front = head;

	void enqueue(T value) {
	    _tail = _tail + 1;
	    if (full) array = array[0 .. _tail] ~ value ~ array[_tail .. $];
	    else {
	        _head %= array.length;
            array[_tail];
	    }
	    ++_length;
	}

	T dequeue()
    in {enforce(!empty, "Queue is empty");}
    do {
        T value = array[_head];
        _head = (_head + 1) % array.length;
        --_length;
        return value;
    }

    void popfront() {
        _head = (_head + 1) % array.length;
        --_length;
    }

	T[] asArray() const @property {
	    if (empty) return [];
	    if(_tail >= _head) return array[_head .. _tail + 1];
	    else return array[_head .. $] ~ array[0 .. _tail +1];
	}

	List opCast(List : T[])() const {
	    return asArray;
	}

	@property auto range() {
		return Queue(this);
	}

    int opApply(scope int delegate(T) dg){
        size_t _h = _head;
        size_t _length = this._length;
        int result = 0;
        while(_length) {
            if(result = dg(array[_h])) return result;
            else {
                _h = (_h + 1) % array.length;
                --_length;
            }
        }
        return result;
    }

}

struct Queue(T, size_t size) if(size > 0) {
private :
    T[size] array;
    size_t _head = 0, _tail = 1;
    size_t _length = 0;
public :
    this(this) {
        array = array.dup;
    }

    this(const T[] list...) {
        _length = list.length;
        _tail = _length - 1;
        _head = 0;
        enforce(_length <= size, "too much item for this Queue");
        array[0.. _length] = list;
    }

    this(const Queue Q) {
        array = Q.array.dup;
        _head = Q._head; _tail = Q._tail; _length = Q._length;
    }

    @property bool empty() const {
        return !_length ;
    }

    @property bool full() const {
        return _length == size ;
    }

    void enqueue(T value)
    in { enforce(!full, "Queue is full"); }
    do {
        _tail = (_tail + 1) % size;
        array[_tail] = value;
        ++_length;
    }

    T dequeue()
    in {enforce(!empty, "Queue is empty");}
    do {
        T value = array[_head];
        _head = (_head + 1) % size;
        --_length;
    }

    T popfront() {
        _head = (_head + 1) % size;
        --_length;
    }

    T head() const @property {
        return array[_head];
    }

    alias front = head;

    size_t length() const @property {
        return _length;
    }

    Queue dup() const {
        return Queue(this);
    }

    auto range() const @ property {
        return Queue(this);
    }

	T[] asArray() const @property {
	    if (empty) return [];
	    if(_tail >= _head) return array[_head .. _tail + 1];
	    else return array[_head .. $] ~ array[0 .. _tail +1];
	}

	List opCast(List : T[])() const {
	    return asArray;
	}

    int opApply(scope int delegate(T) dg){
        size_t _h = _head;
        size_t _length = this._length;
        int result = 0;
        while(_length) {
            if(result = dg(array[_h])) return result;
            else {
                _h = (_h + 1) % array.size;
                --_length;
            }
        }
        return result;
    }

};
