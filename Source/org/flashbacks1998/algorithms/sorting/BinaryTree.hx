package org.flashbacks1998.algorithms.sorting;

// A node in the binary tree
class Node {
    public var x:Int;
    public var y:Int;
    public var w:Int;
    public var h:Int;
    public var used:Bool = false;
    public var right:Node = null;
    public var down:Node = null;

    public function new(x:Int, y:Int, w:Int, h:Int) {
        this.x = x;
        this.y = y;
        this.w = w;
        this.h = h;
    }

    /**
     * Try to insert a rectangle (w,h) into this node or its children.
     * Returns the node where the rect was placed, or null if it doesn't fit.
     */
    public function insert(w:Int, h:Int):Node {
        if (used) {
            // Try children
            var r = (right != null) ? right.insert(w, h) : null;
            if (r != null) return r;
            return (down != null) ? down.insert(w, h) : null;
        } else {
            // If it doesn't fit
            if (w > this.w || h > this.h) return null;

            // Exact fit
            if (w == this.w && h == this.h) {
                used = true;
                return this;
            }

            // Otherwise split this node and create children
            used = true;
            var dw = this.w - w;
            var dh = this.h - h;

            // Decide split direction based on leftover space
            if (dw > dh) {
                // split vertically: right takes leftover width
                right = new Node(this.x + w, this.y, this.w - w, h);
                down  = new Node(this.x, this.y + h, this.w, this.h - h);
            } else {
                // split horizontally: down takes leftover height
                right = new Node(this.x + w, this.y, this.w - w, this.h);
                down  = new Node(this.x, this.y + h, w, this.h - h);
            }

            // shrink this node to the placed size
            this.w = w;
            this.h = h;
            return this;
        }
    }
}

class BinaryTree {
	private var root:Node;

	/**
	 * Create a BinaryTree with the given width and height.
	 */
	public function new(width:Int, height:Int) {
		reset(width, height);
	}

	/**
	 * Reset the tree to a fresh root of width/height.
	 */
	public function reset(width:Int, height:Int):Void {
		root = new Node(0, 0, width, height);
	}

	/**
	 * Attempt to insert a rectangle (w,h) into the tree.
	 * Returns the placement node (with x,y coords) or null if it doesn't fit.
	 */
	public function insert(w:Int, h:Int):{x:Int,y:Int,w:Int,h:Int} {
		var n:Node = root.insert(w, h);
		if (n == null) return null;
		return { x:n.x, y:n.y, w:n.w, h:n.h };
	}
}
