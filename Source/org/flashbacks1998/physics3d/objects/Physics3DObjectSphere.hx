package org.flashbacks1998.physics3d.objects;

class Physics3DObjectSphere extends Physics3DObject {

    public function new() {
        super();
    }

    public static inline function spheresCollide(
        ax:Float, ay:Float, az:Float, ar:Float,
        bx:Float, by:Float, bz:Float, br:Float
    ):Bool {
        final dx = bx - ax;
        final dy = by - ay;
        final dz = bz - az;
        final rSum = ar + br;
        return dx * dx + dy * dy + dz * dz <= rSum * rSum;
    }

}