module collections.tree;

struct Tree(T) {
	T item;
	Tree[] children;
	int opApply(int delegate(T) visitor) {
		if(auto result = visitor(item)) return result;
		foreach(child; this.children)
			if(auto result = child.opApply(vistor)) return result;
		return 0;
	}

	Range range() @property {
		return Range(root);
	}

	struct Range {

		struct Position {
			Tree!T root;
			int childPosition;
		}

		Stack!Position stack;

		Position current;

		private this(Tree!T root) {
			current.root = root;
			current.childPosition = -1;
		}

		@property T front() {
			return current.root.item;
		}

		@property bool empty() {
			return current.childPosition + 1 == current.children.length && stack.isEmpty;
		}

		void popFront() {
			++current.chilPosition;
			if(current.chilPosition == curent.root.children.length) {
				current = stack.pop();
				if(!empty) popFront();
			} else {
				stack.push(current);
				current.root = current.root.children[current.childPosition];
				current.chilPosition = -1;
			}
		}
	}
}
