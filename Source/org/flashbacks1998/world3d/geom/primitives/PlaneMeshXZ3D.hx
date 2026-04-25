package org.flashbacks1998.world3d.geom.primitives;

import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DVertexData;
import org.flashbacks1998.world3d.geom.Mesh3D.Mesh3DIndexData;
import org.flashbacks1998.world3d.geom.Mesh3D.BasicVertexAttributes;
import openfl.Vector;

class PlaneMeshXZ3D extends Mesh3D {
    private static final _defaultIndexRawData:Vector<UInt> = Vector.ofArray([
        cast(0, UInt), cast(2, UInt), cast(1, UInt),
        cast(0, UInt), cast(3, UInt), cast(2, UInt)
    ]);
    
    private static final _defaultVertexRawData:Vector<Float> = Vector.ofArray([
        // X,    Y,    Z,    U,   V,   nx,  ny,  nz
        -1.0,  0.0,  -1.0,  0.0, 0.0,  0.0, 1.0, 0.0,
         1.0,  0.0,  -1.0,  1.0, 0.0,  0.0, 1.0, 0.0,
         1.0,  0.0,  1.0,  1.0, 1.0,  0.0, 1.0, 0.0,
        -1.0,  0.0,  1.0,  0.0, 1.0,  0.0, 1.0, 0.0
    ]);
    

    private static final _defaultVertexAttributes:BasicVertexAttributes = {
        pos3:0,
        uv2: 3,
        norm3: 5
    };

    private static final _defaultIndexData:Mesh3DIndexData = {
        indices: _defaultIndexRawData
    };

    private static final _defaultVertexData:Mesh3DVertexData = {
        vertices: _defaultVertexRawData,
        attributes: _defaultVertexAttributes,
        stride: 8
    };

    public function new() {
        super({vertexData: _defaultVertexData, indexData: _defaultIndexData});
    }
}
