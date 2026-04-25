package org.flashbacks1998.util.interfaces;

//Main goal, use IIndexed to be used for either openfl vector or openfl array
//Example: 
//  var test1:Vector<Int> = new Vector();
//  var test2:IIndexed<Int> = test1;
//  var test2[0] = 8 OR test2.set(0, 8);

//Example: 
//  var test1:Array<Int> = new Array();
//  var test2:IIndexed<Int> = test1;
//  var test2[0] = 8 OR test2.set(0, 8);

//TODO: Lookup :fowrard, :array, :arrayAccess modifiers and other macros

// indexable.hx
@:arrayAccess
abstract IIndexed<T>(Dynamic) {
    @:arrayAccess inline public function get(i:Int):T      return this[i];
    @:arrayAccess inline public function set(i:Int, v:T):T { this[i] = v; return v; }
    inline public function get_length():Int               return this.length;
}
