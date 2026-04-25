package org.flashbacks1998.world3d.geom;

import haxe.macro.Context;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.interfaces.IUploadable3D;
import haxe.ds.ObjectMap;
import openfl.display3D.Context3D;
import openfl.display3D.VertexBuffer3D;
import openfl.display3D.IndexBuffer3D;
import openfl.Vector;
import org.flashbacks1998.world3d.geom.BoundingSphere;
import Std;

typedef BasicVertexAttributes = {
    pos3:UInt,           //Position of vertex
    ?uv2:UInt,           //Texture uv
    ?norm3:UInt,         //Normal dir
    ?kdrgb3:UInt,        //Diffuse color
}

typedef Mesh3DVertexData = {
    stride:UInt,
    attributes:BasicVertexAttributes,
    vertices:Vector<Float>,
}

typedef Mesh3DVertexBuffer = {
    buffer: VertexBuffer3D,
    attributes: BasicVertexAttributes,
}

typedef Mesh3DIndexData = {
    indices:Vector<UInt>,
}

typedef Mesh3DRenderAttributes =  {
    forceToBack:Bool,
}

typedef Mesh3DIndexBuffer = IndexBuffer3D;

class Mesh3D implements IUploadable3D {
    // data -> (context -> buffer)
    private static final _contextVertices:ObjectMap<Mesh3DVertexData, ObjectMap<Context3D, Mesh3DVertexBuffer>> = new ObjectMap();
    private static final _contextIndices:ObjectMap<Mesh3DIndexData, ObjectMap<Context3D, Mesh3DIndexBuffer>> = new ObjectMap();

    public var vertexData:Mesh3DVertexData = null;
    public var vertexBuffer:Mesh3DVertexBuffer = null;

    public var indexData:Mesh3DIndexData = null;
    public var indexBuffer:Mesh3DIndexBuffer = null;

    public var renderAttributes:Mesh3DRenderAttributes;

    // Cached bounding sphere in object-local space (lazy-computed on first use)
    public var boundingSphere:BoundingSphere = null;

    public function new(?options:{
        vertexData:Mesh3DVertexData, indexData:Mesh3DIndexData
    }) {
        this.vertexData = options?.vertexData ?? {
            stride: 8,
            attributes: {pos3: 0, uv2: 3, kdrgb3: 5},
            vertices: new Vector<Float>()
        };

        this.indexData = options?.indexData ?? {
            indices: new Vector<UInt>()
        };
    }

    public function upload(engine:IRendererEngine):Void {
        engine.uploadMesh(this);
    }

    public function uploadToContext(context:Context3D):Void {
        //OK IN JS DONT TRACE ENTIREOBJS
        Debugger.log("uploading...", context.toString());

        // Guard: context must exist
        if (context == null) {
            Debugger.log("Error: context given is null! Returning");
            return;
        }

        // Guard: vertexData and indexData must exist
        if (vertexData == null || indexData == null) {
            Debugger.log("Error: there is no data to upload!", vertexData == null, indexData == null);
            return;
        }

        // If this Mesh3D instance already has buffers assigned, don't recreate them
        if (this.vertexBuffer != null) {
            Debugger.log("Info: this Mesh3D already has a vertexBuffer assigned; skipping creation.");
        }
        if (this.indexBuffer != null) {
            Debugger.log("Info: this Mesh3D already has an indexBuffer assigned; skipping creation.");
        }

        //
        // Vertex buffer — try cache first
        //
        if (vertexData.vertices.length > 0 && this.vertexBuffer == null) {
            var vmap:ObjectMap<Context3D, Mesh3DVertexBuffer> = _contextVertices.get(vertexData);
            if (vmap != null) {
                var cachedVB:Mesh3DVertexBuffer = vmap.get(context);
                if (cachedVB != null) {
                    Debugger.log("Info: found cached vertex buffer for this context; reusing.");
                    this.vertexBuffer = cachedVB;
                }
            }

            if (this.vertexBuffer == null) {
                // create a new vertex buffer and cache it
                var numVerts:Int = Std.int(vertexData.vertices.length / vertexData.stride);
                Debugger.log("creating vertex buffer...", vertexData.vertices.length, vertexData.stride, numVerts);
                var newVB:VertexBuffer3D = context.createVertexBuffer(numVerts, vertexData.stride);
                newVB.uploadFromVector(vertexData.vertices, 0, numVerts);
                var vbRec:Mesh3DVertexBuffer = { buffer: newVB, attributes: vertexData.attributes };

                // ensure vmap exists
                if (vmap == null) {
                    vmap = new ObjectMap();
                    _contextVertices.set(vertexData, vmap);
                }
                vmap.set(context, vbRec);
                this.vertexBuffer = vbRec;
            }
        } else if (vertexData.vertices.length == 0) {
            Debugger.log("Warning: vertex buffer has zero size! Skipping... ");
        }

        //
        // Index buffer — try cache first
        //
        if (indexData.indices.length > 0 && this.indexBuffer == null) {
            var imap:ObjectMap<Context3D, Mesh3DIndexBuffer> = _contextIndices.get(indexData);
            if (imap != null) {
                var cachedIB:Mesh3DIndexBuffer = imap.get(context);
                if (cachedIB != null) {
                    Debugger.log("Info: found cached index buffer for this context; reusing.");
                    this.indexBuffer = cachedIB;
                }
            }

            if (this.indexBuffer == null) {
                Debugger.log("creating index buffer...", indexData.indices.length);
                var newIB:IndexBuffer3D = context.createIndexBuffer(indexData.indices.length);
                newIB.uploadFromVector(indexData.indices, 0, indexData.indices.length);

                if (imap == null) {
                    imap = new ObjectMap();
                    _contextIndices.set(indexData, imap);
                }
                imap.set(context, newIB);
                this.indexBuffer = newIB;
            }
        } else if (indexData.indices.length == 0) {
            Debugger.log("Warning: index buffer has zero size! Skipping... ");
        }
	}

    public function dispose(engine:IRendererEngine):Void {
        // Software engine has no GPU resources to dispose
        // Hardware engine should call disposeFromContext directly
    }

    public function disposeFromContext(context:Context3D):Void {
        Debugger.log("dispose");
        
        if (context == null) {
            Debugger.log("Mesh3D.dispose: context is null, aborting.");
            return;
        }

        //
        // Vertex buffer: clear cache entry for this.vertexData + context
        //
        if (vertexData != null) {
            var vmap:ObjectMap<Context3D, Mesh3DVertexBuffer> = _contextVertices.get(vertexData);
            if (vmap != null) {
                var vbRec:Mesh3DVertexBuffer = vmap.get(context);
                if (vbRec != null && vbRec.buffer != null) {
                    try {
                        vbRec.buffer.dispose();
                    } catch (_:Dynamic) {}
                    vmap.remove(context);
                    Debugger.log("Mesh3D.dispose: disposed vertex buffer for context.");
                }

                // if this vertexData has no more contexts, remove it from the cache
                var it = vmap.iterator();
                if (!it.hasNext()) {
                    _contextVertices.remove(vertexData);
                }
            }
        }

        //
        // Index buffer: clear cache entry for this.indexData + context
        //
        if (indexData != null) {
            var imap:ObjectMap<Context3D, Mesh3DIndexBuffer> = _contextIndices.get(indexData);
            if (imap != null) {
                var ib:Mesh3DIndexBuffer = imap.get(context);
                if (ib != null) {
                    try {
                        ib.dispose();
                    } catch (_:Dynamic) {}
                    imap.remove(context);
                    Debugger.log("Mesh3D.dispose: disposed index buffer for context.");
                }

                // if this indexData has no more contexts, remove it from the cache
                var it2 = imap.iterator();
                if (!it2.hasNext()) {
                    _contextIndices.remove(indexData);
                }
            }
        }

        // Finally, drop instance references
        vertexBuffer = null;
        indexBuffer  = null;
    } 
}
