package org.flashbacks1998.world3d.geom.primitives;

import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DVertexData;
import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DIndexData;
import org.flashbacks1998.world3d.geom.Mesh3D.BasicVertexAttributes;
import openfl.Vector;
import haxe.ds.IntMap;

class BoxMesh3D extends Mesh3D { 
    /**
     * Create an axis-aligned box centered at the origin.
     * width, height, depth are full extents (not half-extents).
     */
    public function new(?width:Float = 1.0, ?height:Float = 1.0, ?depth:Float = 1.0) { 

        // Not cached: build the mesh
        var hw:Float = (width  == null ? 0.5 : width  / 2.0);
        var hh:Float = (height == null ? 0.5 : height / 2.0);
        var hd:Float = (depth  == null ? 0.5 : depth  / 2.0);

        var vertices:Vector<Float> = new Vector<Float>();
        var indices:Vector<UInt> = new Vector<UInt>();

        // Helper to push a single vertex: x,y,z, u,v, nx,ny,nz
        var pushVertex = function(x:Float, y:Float, z:Float, u:Float, v:Float, nx:Float, ny:Float, nz:Float) {
            vertices.push(x);
            vertices.push(y);
            vertices.push(z);
            vertices.push(u);
            vertices.push(v);
            vertices.push(nx);
            vertices.push(ny);
            vertices.push(nz);
        };

        var base:Int = 0;

        // +X face (right)
        pushVertex(hw, -hh, -hd, 0.0, 0.0,  1.0, 0.0, 0.0); // 0
        pushVertex(hw,  hh, -hd, 1.0, 0.0,  1.0, 0.0, 0.0); // 1
        pushVertex(hw,  hh,  hd, 1.0, 1.0,  1.0, 0.0, 0.0); // 2
        pushVertex(hw, -hh,  hd, 0.0, 1.0,  1.0, 0.0, 0.0); // 3
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        // -X face (left)
        pushVertex(-hw, -hh,  hd, 0.0, 0.0, -1.0, 0.0, 0.0);
        pushVertex(-hw,  hh,  hd, 1.0, 0.0, -1.0, 0.0, 0.0);
        pushVertex(-hw,  hh, -hd, 1.0, 1.0, -1.0, 0.0, 0.0);
        pushVertex(-hw, -hh, -hd, 0.0, 1.0, -1.0, 0.0, 0.0);
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        // +Y face (top)
        pushVertex(-hw, hh, -hd, 0.0, 0.0, 0.0, 1.0, 0.0);
        pushVertex(-hw, hh,  hd, 1.0, 0.0, 0.0, 1.0, 0.0);
        pushVertex( hw, hh,  hd, 1.0, 1.0, 0.0, 1.0, 0.0);
        pushVertex( hw, hh, -hd, 0.0, 1.0, 0.0, 1.0, 0.0);
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        // -Y face (bottom)
        pushVertex(-hw, -hh,  hd, 0.0, 0.0, 0.0, -1.0, 0.0);
        pushVertex(-hw, -hh, -hd, 1.0, 0.0, 0.0, -1.0, 0.0);
        pushVertex( hw, -hh, -hd, 1.0, 1.0, 0.0, -1.0, 0.0);
        pushVertex( hw, -hh,  hd, 0.0, 1.0, 0.0, -1.0, 0.0);
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        // +Z face (front)
        pushVertex(-hw, -hh, hd, 0.0, 0.0, 0.0, 0.0, 1.0);
        pushVertex( hw, -hh, hd, 1.0, 0.0, 0.0, 0.0, 1.0);
        pushVertex( hw,  hh, hd, 1.0, 1.0, 0.0, 0.0, 1.0);
        pushVertex(-hw,  hh, hd, 0.0, 1.0, 0.0, 0.0, 1.0);
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        // -Z face (back)
        pushVertex( hw, -hh, -hd, 0.0, 0.0, 0.0, 0.0, -1.0);
        pushVertex(-hw, -hh, -hd, 1.0, 0.0, 0.0, 0.0, -1.0);
        pushVertex(-hw,  hh, -hd, 1.0, 1.0, 0.0, 0.0, -1.0);
        pushVertex( hw,  hh, -hd, 0.0, 1.0, 0.0, 0.0, -1.0);
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 1, UInt)); indices.push(cast(base + 2, UInt));
        indices.push(cast(base + 0, UInt)); indices.push(cast(base + 2, UInt)); indices.push(cast(base + 3, UInt));
        base += 4;

        var attributes:BasicVertexAttributes = {
            pos3: 0,
            uv2:  3,
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

        // Store into cache
        var entry = { vertexData: vertexData, indexData: indexData }; 
        
        // Call parent with the newly-created data
        super(entry);
    }
}
