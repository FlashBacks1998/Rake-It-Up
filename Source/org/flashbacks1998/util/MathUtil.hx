package org.flashbacks1998.util;

class MathUtil {
    public static inline function wrap180(deg:Float):Float {
        var a = (deg + 180) % 360;
        if (a < 0) a += 360;
        return a - 180;
    }

    public static inline function clamp(v:Float, lo:Float, hi:Float):Float {
        return (v < lo) ? lo : (v > hi ? hi : v);
    }
}