module collections.interval;


 struct Interval(T) if(is_floating!T) {
    private T start, end, step;
    private size_t count;

    this(T start, T end, T step = T(1))
	in {
		assert(step != T(0), "step must not be 0");
		assert((end - begin) / step >= T(0), "Interval : incorect startup parameters");
	}
	do {
        import std.conv : to;

        this.start = start;
        this.step = step;
        count = to!size_t((end - start) / step);
        T pastEnd = start + count * step;
        if (step > 0)
        {
            if (pastEnd < end) ++count;
            assert(start + count * step >= end);
        }
        else
        {
            if (pastEnd > end) ++count;
            assert(start + count * step <= end);
        }
    }
	Range range() @property {
		return Range.init;
	}

	T opIndex(size_t index) const {
		assert(index < count);
		return start + index * step;
	} 

	int opApply(int delegate(T) dg) {
		int result = 0;
		foreach(i; 0 .. count) {
			result = dg(start + i * step);
			if(result) return result;
		}
		return result;
	}

	enum size_t opDollar = count;

	struct Range {
		size_t index = 0;
		size_t last = count;
		bool empty() const @property {
			return index == last;
		}
		T front() @property const {
			assert(!empty);
			return start + step * index;
		}
		void popFront() {
			assert(!empty);
			++index;
		}
		T back() @property const {
			assert(!empty);
			return start + step * (last - 1);
		}
		void popBack() {
			assert(!empty);
			--last;
		}
		auto save() @property { return this;}
		T opIndex(size_t n) const {
			assert(n < count);
			return start + step * n;
		}

	}
 }

