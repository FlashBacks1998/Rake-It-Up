package org.flashbacks1998.world3d.camera;

import openfl.Vector;

/**
 * Frustum plane extraction (Gribb-Hartmann) and sphere-frustum testing.
 *
 * Call extractFromMVP() with the combined Model-View-Projection matrix to
 * put the frustum planes into object-local space, then test object-local
 * bounding spheres directly via testSphere().
 */
class Frustum3D {
    // 6 planes x 4 components (a, b, c, d) — normal points inward
    // Order: Left, Right, Bottom, Top, Near, Far
    public var planes:Vector<Float>;

    public function new() {
        planes = new Vector<Float>(24, true);
    }

    /** Extract 6 frustum planes from an MVP matrix (column-major rawData). */
    public function extractFromMVP(m:Vector<Float>):Void {
        // OpenFL Matrix3D rawData is column-major:
        //  m[0] m[4] m[8]  m[12]
        //  m[1] m[5] m[9]  m[13]
        //  m[2] m[6] m[10] m[14]
        //  m[3] m[7] m[11] m[15]
        //
        // Row 0: m[0], m[4], m[8],  m[12]
        // Row 1: m[1], m[5], m[9],  m[13]
        // Row 2: m[2], m[6], m[10], m[14]
        // Row 3: m[3], m[7], m[11], m[15]

        // Left:   row3 + row0
        setPlane(0, m[3] + m[0], m[7] + m[4], m[11] + m[8],  m[15] + m[12]);
        // Right:  row3 - row0
        setPlane(1, m[3] - m[0], m[7] - m[4], m[11] - m[8],  m[15] - m[12]);
        // Bottom: row3 + row1
        setPlane(2, m[3] + m[1], m[7] + m[5], m[11] + m[9],  m[15] + m[13]);
        // Top:    row3 - row1
        setPlane(3, m[3] - m[1], m[7] - m[5], m[11] - m[9],  m[15] - m[13]);
        // Near:   row3 + row2
        setPlane(4, m[3] + m[2], m[7] + m[6], m[11] + m[10], m[15] + m[14]);
        // Far:    row3 - row2
        setPlane(5, m[3] - m[2], m[7] - m[6], m[11] - m[10], m[15] - m[14]);
    }

    /** Returns true if the sphere is (possibly) inside the frustum. */
    public function testSphere(cx:Float, cy:Float, cz:Float, r:Float):Bool {
        var i:Int = 0;
        while (i < 24) {
            final dist:Float = planes[i] * cx + planes[i + 1] * cy + planes[i + 2] * cz + planes[i + 3];
            if (dist < -r) return false;
            i += 4;
        }
        return true;
    }

    private inline function setPlane(idx:Int, a:Float, b:Float, c:Float, d:Float):Void {
        final len:Float = Math.sqrt(a * a + b * b + c * c);
        if (len > 0) {
            final inv:Float = 1.0 / len;
            final o:Int = idx * 4;
            planes[o]     = a * inv;
            planes[o + 1] = b * inv;
            planes[o + 2] = c * inv;
            planes[o + 3] = d * inv;
        }
    }
}
