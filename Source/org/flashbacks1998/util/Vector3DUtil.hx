package org.flashbacks1998.util;

class Vector3DUtil {
    public static inline function crossProductToOutput(a:openfl.geom.Vector3D, b:openfl.geom.Vector3D, out:openfl.geom.Vector3D):Void {
        out.setTo(
            a.y * b.z - a.z * b.y,
            a.z * b.x - a.x * b.z,
            a.x * b.y - a.y * b.x
        );
    }
}