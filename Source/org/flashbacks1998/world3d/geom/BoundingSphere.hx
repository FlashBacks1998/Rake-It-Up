package org.flashbacks1998.world3d.geom;

import openfl.Vector;

class BoundingSphere {
    public var centerX:Float;
    public var centerY:Float;
    public var centerZ:Float;
    public var radius:Float;

    public function new(cx:Float, cy:Float, cz:Float, r:Float) {
        centerX = cx;
        centerY = cy;
        centerZ = cz;
        radius = r;
    }

    /** Compute a bounding sphere from interleaved vertex data (object-local space). */
    public static function fromVertexData(vertices:Vector<Float>, stride:Int, posOffset:Int):BoundingSphere {
        final vertexCount:Int = Std.int(vertices.length / stride);
        if (vertexCount <= 0) return new BoundingSphere(0, 0, 0, 0);

        // Pass 1: centroid
        var sx:Float = 0;
        var sy:Float = 0;
        var sz:Float = 0;
        var i:Int = 0;
        while (i < vertexCount) {
            final base:Int = i * stride + posOffset;
            sx += vertices[base];
            sy += vertices[base + 1];
            sz += vertices[base + 2];
            i++;
        }
        final inv:Float = 1.0 / vertexCount;
        final cx:Float = sx * inv;
        final cy:Float = sy * inv;
        final cz:Float = sz * inv;

        // Pass 2: max squared distance from centroid
        var maxDistSq:Float = 0;
        i = 0;
        while (i < vertexCount) {
            final base:Int = i * stride + posOffset;
            final dx:Float = vertices[base] - cx;
            final dy:Float = vertices[base + 1] - cy;
            final dz:Float = vertices[base + 2] - cz;
            final distSq:Float = dx * dx + dy * dy + dz * dz;
            if (distSq > maxDistSq) maxDistSq = distSq;
            i++;
        }

        return new BoundingSphere(cx, cy, cz, Math.sqrt(maxDistSq));
    }
}
