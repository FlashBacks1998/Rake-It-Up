package org.flashbacks1998.util;

import openfl.display.BitmapData;
import openfl.Vector;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;


class Constants {
    /** Unit X axis (1, 0, 0) */
    public static final VECTOR3D_POSX:Vector3D = new Vector3D(1, 0, 0);
    /** Unit Y axis (0, 1, 0) */
    public static final VECTOR3D_POSY:Vector3D = new Vector3D(0, 1, 0);
    /** Unit Z axis (0, 0, 1) */
    public static final VECTOR3D_POSZ:Vector3D = new Vector3D(0, 0, 1);

    /** Multiply radians by this to get degrees. */
    public static final RADIANS_TO_DEGREES:Float = 180.0 / Math.PI;
    /** Multiply degrees by this to get radians. */
    public static final DEGREES_TO_RADIANS:Float = Math.PI / 180.0;

    public static final FLOAT_EPSILON:Float = 1e-6;

    public static final MATRIX_IDENTITY:Matrix3D = new Matrix3D(Vector.ofArray([
        1.0, 0.0, 0.0, 0.0, // column 0
        0.0, 1.0, 0.0, 0.0, // column 1
        0.0, 0.0, 1.0, 0.0, // column 2
        0.0, 0.0, 0.0, 1.0  // column 3
    ]));

    /**
        * Build a BitmapData filled with the colorAt pattern.
        * drawGrid/girdInterval left out for simplicity, but you can add them back if needed.
        */
    public static function makeBitmap(width:Int, height:Int, ?gamma:Float = 1.0):BitmapData {
        var bmp = new BitmapData(width, height, true, 0xFF000000);

        function colorAt(width:Int, height:Int, x:Int, y:Int, ?gamma:Float = 1.0):Int {
            if (width <= 1 || height <= 1) {
                // degenerate image: return black for safety
                return 0xFF000000;
            }
    
            // normalized coordinates u (horizontal), v (vertical) in [0,1]
            var u:Float = x / (width - 1);
            var v:Float = y / (height - 1);
    
            // With the specified corner values the bilinear interpolation simplifies to:
            // r = u * (1 - v)
            // g = (1 - u) * v
            // b = u * v
            var r:Float = u * (1.0 - v);
            var g:Float = (1.0 - u) * v;
            var b:Float = u * v;
    
            // optional gamma correction (apply same convention as your original code: pow(value, gamma))
            if (gamma > 0.0 && gamma != 1.0) {
                r = Math.pow(r, gamma);
                g = Math.pow(g, gamma);
                b = Math.pow(b, gamma);
            }
    
            // convert to 0..255 ints (clamp + round)
            var Ri:Int = Std.int(Math.min(255, Math.max(0, Math.round(r * 255.0))));
            var Gi:Int = Std.int(Math.min(255, Math.max(0, Math.round(g * 255.0))));
            var Bi:Int = Std.int(Math.min(255, Math.max(0, Math.round(b * 255.0))));
    
            var A:Int = 0xFF;
            return (A << 24) | (Ri << 16) | (Gi << 8) | Bi;
        }

        for (y in 0...height) {
            for (x in 0...width) {
                bmp.setPixel32(x, y, colorAt(width, height, x, y, gamma));
            }
        }
        return bmp;
    } 
}
