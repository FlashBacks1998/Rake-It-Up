package org.flashbacks1998.world3d.geom.primitives;
 
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DVertexData;
import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DIndexData;
import org.flashbacks1998.world3d.geom.Mesh3D.BasicVertexAttributes;
import openfl.Vector;
import Math;

class SphereMesh3D extends Mesh3D {
    /**
     * Create a sphere mesh (Y is UP).
     *
     * @param subdivisions        Number of latitude subdivisions (>=3). Horizontal subdivisions = subdivisions*2.
     * @param radius              Sphere radius (default 1.0).
     * @param removeBottomPercent Percent (0..100) removed from the bottom (0 = keep bottom, 50 = remove lower half).
     * @param removeTopPercent    Percent (0..100) removed from the top (0 = keep top, 50 = remove upper half).
     *
     * Examples:
     *  new(16,1.0)                         -> full sphere
     *  new(16,1.0, 50, 0)                  -> bottom half removed (keeps top half)
     *  new(16,1.0, 0, 50)                  -> top half removed (keeps bottom half)
     *  new(16,1.0, 25, 25)                 -> keeps the middle 50% band
     */
    public function new(?subdivisions:Int = 16,
                        ?radius:Float = 1.0,
                        ?removeBottomPercent:Float = 0.0,
                        ?removeTopPercent:Float = 0.0) {
        var latSeg:Int = subdivisions; //Std.int(Math.max(3, subdivisions));
        var lonSeg:Int = subdivisions* 2; //Std.int(Math.max(6, subdivisions * 2));

        // clamp inputs 0..100
        removeBottomPercent = Math.max(0.0, Math.min(100.0, removeBottomPercent));
        removeTopPercent    = Math.max(0.0, Math.min(100.0, removeTopPercent));

        // Convert removals -> kept-band percents measured from bottom (0) to top (100)
        // keptTopPercent = 100 - removeTopPercent
        // keptBottomPercent = removeBottomPercent
        var keptTopPercent:Float = 100.0 - removeTopPercent;
        var keptBottomPercent:Float = removeBottomPercent;

        // Make sure keptTop >= keptBottom; swap if user gave removals that invert the band
        if (keptTopPercent < keptBottomPercent) {
            var tmp = keptTopPercent;
            keptTopPercent = keptBottomPercent;
            keptBottomPercent = tmp;
        }

        // Convert kept percents (0..100) -> normalized Y (-1..1)
        var topNorm:Float = (keptTopPercent / 100.0) * 2.0 - 1.0;     // 100 -> +1, 0 -> -1
        var bottomNorm:Float = (keptBottomPercent / 100.0) * 2.0 - 1.0;

        // Convert normalized Y to theta angles (Y = r * cos(theta))
        var thetaStart:Float = Math.acos(Math.max(-1.0, Math.min(1.0, topNorm)));     // near 0 for top
        var thetaEnd:Float   = Math.acos(Math.max(-1.0, Math.min(1.0, bottomNorm)));  // near PI for bottom
        var thetaRange:Float = thetaEnd - thetaStart;
        if (thetaRange == 0) thetaRange = 1e-6;

        var vertices:Vector<Float> = new Vector<Float>();
        var indices:Vector<UInt> = new Vector<UInt>();

        // Vertex generation (Y-up):
        // x = r * sinθ * cosφ
        // y = r * cosθ
        // z = r * sinθ * sinφ
        for (i in 0... (latSeg + 1)) {
            var t:Float = i / latSeg; // 0..1 across chosen lat range
            var theta:Float = thetaStart + thetaRange * t; // in [thetaStart..thetaEnd]
            var sinTheta:Float = Math.sin(theta);
            var cosTheta:Float = Math.cos(theta);

            for (j in 0... (lonSeg + 1)) {
                var s:Float = j / lonSeg;
                var phi:Float = 2.0 * Math.PI * s; // 0..2PI

                var cosPhi = Math.cos(phi);
                var sinPhi = Math.sin(phi);

                var x:Float = radius * sinTheta * cosPhi;
                var y:Float = radius * cosTheta;
                var z:Float = radius * sinTheta * sinPhi;

                // Normals for unit sphere
                var nx:Float = (radius != 0) ? (x / radius) : 0;
                var ny:Float = (radius != 0) ? (y / radius) : 1;
                var nz:Float = (radius != 0) ? (z / radius) : 0;

                // UVs: u around 0..1, v from bottom->top (0..1)
                var v:Float = (theta - thetaStart) / thetaRange; // thetaStart (top) -> 0 ; thetaEnd (bottom) -> 1
                v = 1.0 - v; // invert so bottom -> 0, top -> 1
                var u:Float = s;

                vertices.push(x);
                vertices.push(y);
                vertices.push(z);

                vertices.push(u);
                vertices.push(v);

                vertices.push(nx);
                vertices.push(ny);
                vertices.push(nz);
            }
        }

        // Indices: two triangles per quad
        var rowSize = lonSeg + 1;
        for (i in 0... latSeg) {
            for (j in 0... lonSeg) {
                var a = i * rowSize + j;
                var b = a + 1;
                var c = (i + 1) * rowSize + j;
                var d = c + 1;

                // Triangle 1: a, b, c
                indices.push(cast(a, UInt));
                indices.push(cast(b, UInt));
                indices.push(cast(c, UInt));

                // Triangle 2: b, d, c
                indices.push(cast(b, UInt));
                indices.push(cast(d, UInt));
                indices.push(cast(c, UInt));
            }
        }

        var attributes:BasicVertexAttributes = {
            pos3: 0,
            uv2: 3,
            norm3: 5
        };

        var vertexData:Mesh3DVertexData = {
            stride: 8,
            attributes: attributes,
            vertices: vertices
        };

        var indexData:Mesh3DIndexData = {
            indices: indices
        };

        super({vertexData: vertexData, indexData: indexData});
    }
}
