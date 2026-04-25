package org.flashbacks1998.util;

import openfl.geom.Vector3D;
import openfl.Vector;

class Matrix3DUtil {
    public static var _d:Vector<Float> = new Vector(16, true);
    public static inline function deltaTransformVectorToOutput(m:openfl.geom.Matrix3D, v:openfl.geom.Vector3D, out:openfl.geom.Vector3D):Vector3D {
        // Assumes rawData is column-major like OpenFL/Flash:
        // rawData: [ m11, m12, m13, m14,
        //            m21, m22, m23, m24,
        //            m31, m32, m33, m34,
        //            m41, m42, m43, m44 ]
        // Copy to _d because the garbage collector is going to CRASH if we dont copy to ref
        // NOTE: m.copyRawDataTo REPLACES the data
        m.copyRawDataTo(_d);

        // multiply 3x3 upper-left (ignore translation)
        out.setTo(
            v.x * _d[0] + v.y * _d[4] + v.z * _d[8],
            v.x * _d[1] + v.y * _d[5] + v.z * _d[9],
            v.x * _d[2] + v.y * _d[6] + v.z * _d[10]
        ); 

        return out;
    }

    public static inline function transformVectorToOutput(
        m:openfl.geom.Matrix3D,
        v:openfl.geom.Vector3D,
        out:openfl.geom.Vector3D
    ):Vector3D {
        m.copyRawDataTo(_d);

        var x = v.x;
        var y = v.y;
        var z = v.z;
        var w = v.w; // for normal points you’ll usually set this to 1

        out.setTo(
            x * _d[0] + y * _d[4] + z * _d[8]  + w * _d[12],
            x * _d[1] + y * _d[5] + z * _d[9]  + w * _d[13],
            x * _d[2] + y * _d[6] + z * _d[10] + w * _d[14]
        );

        // OpenFL Vector3D.setTo doesn't touch w, so set it manually:
        out.w = x * _d[3] + y * _d[7] + z * _d[11] + w * _d[15];

        return out;
    }
}