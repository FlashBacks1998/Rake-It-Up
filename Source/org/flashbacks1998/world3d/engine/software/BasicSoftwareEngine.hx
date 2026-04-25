package org.flashbacks1998.world3d.engine.software;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import openfl.display.BitmapData;
import openfl.display3D.Program3D;
import openfl.display3D.textures.TextureBase;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import haxe.ds.ObjectMap;
import org.flashbacks1998.world3d.camera.Camera3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import org.flashbacks1998.world3d.geom.BoundingSphere;
import org.flashbacks1998.world3d.camera.Frustum3D;
import openfl.Lib;
import openfl.Vector;
import openfl.utils.Future;
import openfl.display.Sprite;
import openfl.display.IGraphicsData;
import openfl.display.GraphicsBitmapFill;
import openfl.display.GraphicsEndFill;
import openfl.display.GraphicsSolidFill;
import openfl.display.GraphicsTrianglePath;

typedef RenderPool = {
    vertexData:Vector<Float>,
    indexData:Vector<Int>,
    uvtData:Vector<Float>,
    viewZ:Vector<Float>,
    depthData:Vector<Float>,
    material:BitmapData,
    triCount:Int,
    forceToBack:Bool,
}

typedef MeshPoolBuffers = {
    vertexData:Vector<Float>,
    indexData:Vector<Int>,
    uvtData:Vector<Float>,
    depthData:Vector<Float>,
    viewX:Vector<Float>,
    viewY:Vector<Float>,
    viewZ:Vector<Float>,
    outcodes:Vector<Int>,
    // Cache validation: skip re-projection when nothing moved
    lastCameraIter:Int,
    lastPositionIter:Int,
    lastTriCount:Int,
    lastMaterial:BitmapData,
    // Batching metadata (set at end of drawMeshPair cache-miss path)
    usedVertexCount:Int,
    usedTextured:Bool,
    forceToBack:Bool,
}

typedef BatchBucket = {
    mesh:Mesh3D,
    material:BitmapData,
    forceToBack:Bool,
    textured:Bool,
    pools:Array<MeshPoolBuffers>,
    triCounts:Array<Int>,
    count:Int,
    totalVerts:Int,
    totalTris:Int,
    // Persistent combined vectors (reused across frames, avoids re-allocation)
    combinedVertexData:Vector<Float>,
    combinedIndexData:Vector<Int>,
    combinedUvtData:Vector<Float>,
    combinedDepthData:Vector<Float>,
}

typedef DeferredDrawCommand = {
    bitmapFill:GraphicsBitmapFill,
    solidFill:GraphicsSolidFill,
    trianglePath:GraphicsTrianglePath,
    endFill:GraphicsEndFill,
    indices:Vector<Int>,
}

class BasicSoftwareEngine implements IRendererEngine {
    // Per-vertex clip outcode bits
    static inline var CLIP_NEAR:Int   = 1;
    static inline var CLIP_LEFT:Int   = 4;
    static inline var CLIP_RIGHT:Int  = 8;
    static inline var CLIP_BOTTOM:Int = 16;
    static inline var CLIP_TOP:Int    = 32;

    private var _frameCamera:Camera3D;
    public var container:Sprite;

    // ---- Pooled buffers per mesh (list allows same mesh to be rendered multiple times per frame)
    public var meshPoolLists:ObjectMap<Mesh3D, Array<MeshPoolBuffers>> = new ObjectMap();
    private var meshPoolCounters:ObjectMap<Mesh3D, Int> = new ObjectMap();

    // Touched meshes this frame (avoids ObjectMap.keys() iterator allocation in render)
    private var _touchedMeshes:Array<Mesh3D> = [];
    private var _touchedMeshCount:Int = 0;

    public var renderQueue:Array<RenderPool> = [];
    private var renderQueueCount:Int = 0;

    // RenderPool object reuse (avoids per-frame GC pressure from anonymous structs)
    private var renderPoolFreeList:Array<RenderPool> = [];
    private var renderPoolUsed:Int = 0;

    // Optional debug
    public var cullingTris:Vector<Int> = new Vector();

    // Per-pool sort buffer (reused each frame)
    var sortedIndices:Vector<Int> = new Vector<Int>();

    // K-way merge buffers
    var poolSortOrders:Array<Array<Int>> = [];
    var poolCursors:Array<Int> = [];

    // Heap merge state (reused per frame)
    private var _heapPool:Vector<Int> = new Vector<Int>();
    private var _heapDepth:Vector<Float> = new Vector<Float>();
    private var _heapSize:Int = 0;

    // Sort state: avoids per-pool closure allocation in drawPool
    var _sortDepthRef:Vector<Float>;
    var _depthSortFn:(Int, Int) -> Int;

    // Cached texture lookups per shader (avoids per-frame Std.isOfType iteration)
    var textureCache:ObjectMap<Dynamic, BitmapData> = new ObjectMap();

    // Reusable frustum for object-level culling
    private var _frustum:Frustum3D = new Frustum3D();

    // Reusable buffer for MVP raw data (avoids per-call rawData allocation on Flash)
    private var _mvpRawBuf:Vector<Float> = new Vector<Float>(16, true);

    public var screenWidth:Float;
    public var screenHeight:Float;

    // If your textures appear upside-down, set this to true.
    public var flipV:Bool = false;

    // Adaptive subdivision: triangles covering more than this fraction of screen area get subdivided.
    public var subdivideThreshold:Float = 0.05;

    /** When true, uses a binary heap for the k-way merge (O(T log P)).
        When false, uses the original linear scan (O(T * P)). */
    public var useHeapMerge:Bool = true;

    /** When true, groups compatible tiny mesh pools into combined RenderPools. */
    public var batchMeshesTogether:Bool = true;
    /** Minimum instance count per bucket to justify batching overhead. */
    public var batchMinInstances:Int = 16;
    /** Maximum post-clip triangle count per instance to be batch-eligible. */
    public var batchMaxTriCountPerInstance:Int = 8;
    /** Maximum post-clip vertex count per instance to be batch-eligible. */
    public var batchMaxVertCountPerInstance:Int = 8;
    /** Hard cap on total triangles in a single combined batch pool. */
    public var batchMaxTotalTrisPerBucket:Int = 4096;
    /** Hard cap on total vertices in a single combined batch pool. */
    public var batchMaxTotalVertsPerBucket:Int = 4096;

    // Batch bucket storage (reused across frames)
    private var _batchBucketsByMesh:ObjectMap<Mesh3D, Array<BatchBucket>> = new ObjectMap();
    private var _activeBatchBuckets:Array<BatchBucket> = [];
    private var _activeBatchBucketCount:Int = 0;

    // Deferred Graphics.drawGraphicsData submission state
    private var _graphicsData:Vector<IGraphicsData> = new Vector<IGraphicsData>();
    private var _graphicsDataCount:Int = 0;
    private var _drawCommandPool:Array<DeferredDrawCommand> = [];
    private var _drawCommandUsed:Int = 0;

    // Frame-local state for near-plane clipping (avoids closure allocation)
    var _nextVert:Int = 0;
    var _clipViewX:Vector<Float>;
    var _clipViewY:Vector<Float>;
    var _clipViewZ:Vector<Float>;
    var _clipVertexData:Vector<Float>;
    var _clipUvtData:Vector<Float>;
    var _clipNear:Float = 0;
    var _clipEps:Float = 0;
    var _clipSw:Float = 0;
    var _clipSh:Float = 0;
    var _clipUseTextured:Bool = false;

    // Frame-local state for deferred UVT computation
    var _srcVerts:Vector<Float>;
    var _uvStride:Int = 0;
    var _uvOffset:Int = 0;
    var _baseVertexCount:Int = 0;
    var _uvtComputed:Vector<Bool> = new Vector<Bool>();

    public var type:BasicRendererEngineType = BasicRendererEngineType.software;

    public function new(width:Float, height:Float, ?container:Sprite) {
        screenWidth = width;
        screenHeight = height;
        this.container = container ?? new Sprite();
        // Create sort comparator once — avoids per-pool closure allocation in drawPool.
        // Reads _sortDepthRef (set before each sort call) via captured `this`.
        _depthSortFn = function(a:Int, b:Int):Int {
            var da = _sortDepthRef[a];
            var db = _sortDepthRef[b];
            return (db > da) ? 1 : ((db < da) ? -1 : 0);
        };
    }

    // ------------------------------------------------------------------
    // IRendererEngine
    // ------------------------------------------------------------------

    public var ready(get, null):Bool;
    public var contextVersion(get, null):Int;

    public var width(get, set):Int;
    public var height(get, set):Int;


    function get_ready():Bool {
        return true;
    }

    function get_contextVersion():Int { return 0; }

    function get_width():Int {
        return Std.int(screenWidth);
    }

    function set_width(width:Int):Int {
        resize(width, Std.int(screenHeight));
        screenWidth = width;
        return width;
    }

    function get_height():Int {
        return Std.int(screenHeight);
    }

    function set_height(height:Int):Int {
        resize(Std.int(screenWidth), height);
        screenHeight = height;
        return height;
    }

    public function onAddedToStage():Void {
        if (!Lib.current.stage.contains(container)) {
            Lib.current.stage.addChild(container);
            Lib.current.stage.setChildIndex(container, 0);
        }
    }

    public function onRemovedFromStage():Void {
        if (Lib.current.stage.contains(container))
            Lib.current.stage.removeChild(container);
    }

    public function onEntityAdded(entity:IEntity3D):Void {}

    public function onEntityRemoved(entity:IEntity3D):Void {}

    public function resize(width:Int, height:Int):Void {
        screenWidth = width;
        screenHeight = height;
    }

    public function dispose():Void {
        meshPoolLists = new ObjectMap();
        meshPoolCounters = new ObjectMap();
        renderQueue.resize(0);
        renderQueueCount = 0;
        renderPoolFreeList.resize(0);
        renderPoolUsed = 0;
        textureCache = new ObjectMap();
        _frameCamera = null;
        container = null;
    }

    // ---- RenderPool reuse: grab from free list or allocate new
    private function acquireRenderPool():RenderPool {
        if (renderPoolUsed < renderPoolFreeList.length) {
            var pool = renderPoolFreeList[renderPoolUsed];
            renderPoolUsed++;
            return pool;
        }
        var pool:RenderPool = {
            vertexData: new Vector<Float>(),
            indexData: new Vector<Int>(),
            uvtData: new Vector<Float>(),
            viewZ: new Vector<Float>(),
            depthData: new Vector<Float>(),
            material: null,
            triCount: 0,
            forceToBack: false,
        };
        renderPoolFreeList.push(pool);
        renderPoolUsed++;
        return pool;
    }

    private inline function enqueueRenderPool(rp:RenderPool):Void {
        if (renderQueueCount >= renderQueue.length)
            renderQueue.push(rp);
        else
            renderQueue[renderQueueCount] = rp;
        renderQueueCount++;
    }

    // ------------------------------------------------------------------
    // IRendererEngine resource methods (no-ops for software)
    // ------------------------------------------------------------------

    public function uploadMesh(mesh:Mesh3D):Void {}

    public function uploadTexture(bitmapData:BitmapData):TextureBase {
        return null;
    }

    public function uploadProgram(vertexAGAL:String, fragmentAGAL:String):Future<Program3D> {
        return Future.withValue(null);
    }

    // IRendererEngine.drawMesh — called from ShaderPipeline.render via engine.drawMesh
    // Passes the MVP matrix so the software rasterizer uses the correct world transform
    public function drawMesh(mesh:Mesh3D, shader:IShader3D, ?matrix:Matrix3D, ?options:Dynamic):Void {
        //trace("DRAW");
        drawMeshPair({ mesh: mesh, shader: shader }, null, matrix);
    }

    // ---- Backface cull via screen-space winding (2D cross product)
    private inline function isBackface(vertexData:Vector<Float>, a:Int, b:Int, c:Int):Bool {
        var a2 = a << 1;
        var b2 = b << 1;
        var c2 = c << 1;

        var ax = vertexData[a2];
        var ay = vertexData[a2 + 1];

        var e1x = vertexData[b2]     - ax;
        var e1y = vertexData[b2 + 1] - ay;
        var e2x = vertexData[c2]     - ax;
        var e2y = vertexData[c2 + 1] - ay;

        // Positive cross => CCW in screen space => front-facing
        // Negative or zero => CW => back-facing (or degenerate)
        return (e1x * e2y - e1y * e2x) <= 0;
    }

    // ---- Screen bbox reject (fully outside viewport)
    private inline function isOffscreen(vertexData:Vector<Float>, a:Int, b:Int, c:Int, sw:Float, sh:Float):Bool {
        var a2 = a << 1;
        var b2 = b << 1;
        var c2 = c << 1;

        var ax = vertexData[a2];
        var ay = vertexData[a2 + 1];
        var bx = vertexData[b2];
        var by = vertexData[b2 + 1];
        var cx = vertexData[c2];
        var cy = vertexData[c2 + 1];

        var minX = ax; var maxX = ax;
        var minY = ay; var maxY = ay;

        if (bx < minX) minX = bx; else if (bx > maxX) maxX = bx;
        if (by < minY) minY = by; else if (by > maxY) maxY = by;

        if (cx < minX) minX = cx; else if (cx > maxX) maxX = cx;
        if (cy < minY) minY = cy; else if (cy > maxY) maxY = cy;

        return (maxX < 0 || minX > sw || maxY < 0 || minY > sh);
    }

    // ---- Append tri with backface + bbox reject
    private inline function appendTri(
        indexData:Vector<Int>,
        w:Int,
        vertexData:Vector<Float>,
        a:Int, b:Int, c:Int,
        sw:Float, sh:Float
    ):Int {
        if (isBackface(vertexData, a, b, c)) return w;
        if (isOffscreen(vertexData, a, b, c, sw, sh)) return w;

        indexData[w] = a;
        indexData[w + 1] = b;
        indexData[w + 2] = c;
        return w + 3;
    }

    // Adaptive subdivision: if a triangle covers more than subdivideThreshold of screen area,
    // split it into 4 sub-triangles via midpoint subdivision. Max depth prevents explosion.
    private function subdivideTri(
        indexData:Vector<Int>,
        w:Int,
        vertexData:Vector<Float>,
        a:Int, b:Int, c:Int,
        sw:Float, sh:Float,
        depth:Int
    ):Int {
        if (isBackface(vertexData, a, b, c)) return w;
        if (isOffscreen(vertexData, a, b, c, sw, sh)) return w;

        if (depth < 5) {
            final a2:Int = a << 1;
            final b2:Int = b << 1;
            final c2:Int = c << 1;

            final ax:Float = vertexData[a2];
            final ay:Float = vertexData[a2 + 1];
            final bx:Float = vertexData[b2];
            final by:Float = vertexData[b2 + 1];
            final cx:Float = vertexData[c2];
            final cy:Float = vertexData[c2 + 1];

            final cross:Float = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax);
            final area:Float = (cross < 0 ? -cross : cross) * 0.5;
            final screenArea:Float = sw * sh;

            if (area > subdivideThreshold * screenArea) {
                final ab:Int = createMidpointVertex(a, b);
                final bc:Int = createMidpointVertex(b, c);
                final ca:Int = createMidpointVertex(c, a);

                w = subdivideTri(indexData, w, vertexData, a, ab, ca, sw, sh, depth + 1);
                w = subdivideTri(indexData, w, vertexData, ab, b, bc, sw, sh, depth + 1);
                w = subdivideTri(indexData, w, vertexData, ca, bc, c, sw, sh, depth + 1);
                w = subdivideTri(indexData, w, vertexData, ab, bc, ca, sw, sh, depth + 1);
                return w;
            }
        }

        // Small enough or max depth — emit directly
        if (w + 3 > indexData.length) indexData.length = (w + 3) * 2;
        indexData[w] = a;
        indexData[w + 1] = b;
        indexData[w + 2] = c;
        return w + 3;
    }

    private inline function findUvOffset(mesh:Mesh3D):Int {
        if (mesh == null || mesh.vertexData == null) return -1;
        var attrs = mesh.vertexData.attributes;
        if (attrs == null) return -1;
        var uv = attrs.uv2;
        return (uv != null) ? cast uv : -1;
    }

    // Compute Flash-style-ish t using "screen plane at near":
    // t = near / vz  (clamped to avoid >1 when vz is very small)
    private inline function computeT(vz:Float, nearPlane:Float, eps:Float):Float {
        var z = vz;
        if (z < nearPlane) z = nearPlane;
        if (z < eps) z = eps;
        return nearPlane / z; // in (0..1] for vz >= near
    }

    // Lazily compute UVT for an original vertex (not clipped/subdivided).
    // Must be called before intersectVertex or createMidpointVertex reads from this vertex's UVT.
    private inline function ensureUvt(idx:Int):Void {
        if (idx < _baseVertexCount && !_uvtComputed[idx]) {
            final baseUV:Int = idx * _uvStride + _uvOffset;
            var u:Float = _srcVerts[baseUV];
            var v:Float = _srcVerts[baseUV + 1];
            if (flipV) v = 1.0 - v;
            final u3:Int = idx * 3;
            _clipUvtData[u3]     = u;
            _clipUvtData[u3 + 1] = v;
            _clipUvtData[u3 + 2] = computeT(_clipViewZ[idx], _clipNear, _clipEps);
            _uvtComputed[idx] = true;
        }
    }

    // Near-plane intersection: creates a new clipped vertex, interpolates UVs.
    // viewX/viewY store clip-space cx/cy, viewZ stores clip-space cw.
    // Interpolates in clip space and perspective-divides directly.
    private function intersectVertex(a:Int, b:Int):Int {
        // viewZ stores cw (clip.w ≈ viewZ for standard perspective)
        final aw:Float = _clipViewZ[a];
        final bw:Float = _clipViewZ[b];
        final denom:Float = (bw - aw);
        if (denom == 0) return a;

        var f:Float = (_clipNear - aw) / denom;
        if (f < 0.0) f = 0.0;
        if (f > 1.0) f = 1.0;

        // Interpolate clip-space coordinates
        final ax:Float = _clipViewX[a];
        final ay:Float = _clipViewY[a];
        final bx:Float = _clipViewX[b];
        final by:Float = _clipViewY[b];

        final cx:Float = ax + f * (bx - ax);
        final cy:Float = ay + f * (by - ay);
        final cw:Float = _clipNear;

        if (cw <= _clipEps) return a;

        final needLen:Int = (_nextVert + 1) * 2;
        if (_clipVertexData.length < needLen) _clipVertexData.length = needLen * 2;

        final invW:Float = 1.0 / cw;
        final ndcX:Float = cx * invW;
        final ndcY:Float = cy * invW;

        final out:Int = _nextVert;
        final o2:Int = out << 1;
        _clipVertexData[o2]     = (ndcX * 0.5 + 0.5) * _clipSw;
        _clipVertexData[o2 + 1] = (1.0 - (ndcY * 0.5 + 0.5)) * _clipSh;

        if (_clipUseTextured) {
            final needUvt:Int = (_nextVert + 1) * 3;
            if (_clipUvtData.length < needUvt) _clipUvtData.length = needUvt * 2;

            final a3:Int = a * 3;
            final b3:Int = b * 3;
            final o3:Int = out * 3;

            _clipUvtData[o3]     = _clipUvtData[a3]     + f * (_clipUvtData[b3]     - _clipUvtData[a3]);
            _clipUvtData[o3 + 1] = _clipUvtData[a3 + 1] + f * (_clipUvtData[b3 + 1] - _clipUvtData[a3 + 1]);
            _clipUvtData[o3 + 2] = computeT(cw, _clipNear, _clipEps);
        }

        if (_clipViewZ.length <= _nextVert) _clipViewZ.length = (_nextVert + 1) * 2;
        _clipViewZ[out] = _clipNear;

        _nextVert++;
        return out;
    }

    // Create a midpoint vertex between a and b (screen-space subdivision).
    // Interpolates screen pos, UVT, and clip-space w at f=0.5.
    private function createMidpointVertex(a:Int, b:Int):Int {
        final a2:Int = a << 1;
        final b2:Int = b << 1;

        final needLen:Int = (_nextVert + 1) * 2;
        if (_clipVertexData.length < needLen) _clipVertexData.length = needLen * 2;

        final out:Int = _nextVert;
        final o2:Int = out << 1;
        _clipVertexData[o2]     = (_clipVertexData[a2]     + _clipVertexData[b2])     * 0.5;
        _clipVertexData[o2 + 1] = (_clipVertexData[a2 + 1] + _clipVertexData[b2 + 1]) * 0.5;

        if (_clipUseTextured) {
            final needUvt:Int = (_nextVert + 1) * 3;
            if (_clipUvtData.length < needUvt) _clipUvtData.length = needUvt * 2;

            final a3:Int = a * 3;
            final b3:Int = b * 3;
            final o3:Int = out * 3;

            // Perspective-correct UV interpolation weighted by t (= near/w = 1/depth)
            final ta:Float = _clipUvtData[a3 + 2];
            final tb:Float = _clipUvtData[b3 + 2];
            final tSum:Float = ta + tb;
            if (tSum > 0) {
                _clipUvtData[o3]     = (_clipUvtData[a3] * ta + _clipUvtData[b3] * tb) / tSum;
                _clipUvtData[o3 + 1] = (_clipUvtData[a3 + 1] * ta + _clipUvtData[b3 + 1] * tb) / tSum;
            } else {
                _clipUvtData[o3]     = (_clipUvtData[a3]     + _clipUvtData[b3])     * 0.5;
                _clipUvtData[o3 + 1] = (_clipUvtData[a3 + 1] + _clipUvtData[b3 + 1]) * 0.5;
            }

            // t (= near/w) varies linearly in screen space, so the correct
            // value at the screen midpoint is the arithmetic mean of the t's.
            _clipUvtData[o3 + 2] = (ta + tb) * 0.5;
        }

        if (_clipViewZ.length <= _nextVert) _clipViewZ.length = (_nextVert + 1) * 2;
        _clipViewZ[out] = (_clipViewZ[a] + _clipViewZ[b]) * 0.5;

        _nextVert++;
        return out;
    }

    // ---- Pool batching: collect compatible tiny pools into combined RenderPools ----

    private inline function shouldBatchPool(pool:MeshPoolBuffers, triCount:Int):Bool {
        return batchMeshesTogether
            && triCount > 0
            && triCount <= batchMaxTriCountPerInstance
            && pool.usedVertexCount <= batchMaxVertCountPerInstance;
    }

    private function collectBatchPool(
        mesh:Mesh3D,
        pool:MeshPoolBuffers,
        material:BitmapData,
        triCount:Int,
        forceToBack:Bool,
        textured:Bool
    ):Void {
        var bucketList = _batchBucketsByMesh.get(mesh);
        if (bucketList == null) {
            bucketList = [];
            _batchBucketsByMesh.set(mesh, bucketList);
        }

        // Find matching bucket that hasn't hit its size cap
        var bucket:BatchBucket = null;
        for (b in bucketList) {
            if (b.material == material && b.forceToBack == forceToBack && b.textured == textured
                && b.totalTris + triCount <= batchMaxTotalTrisPerBucket
                && b.totalVerts + pool.usedVertexCount <= batchMaxTotalVertsPerBucket) {
                bucket = b;
                break;
            }
        }

        if (bucket == null) {
            // Create new bucket (persists across frames)
            bucket = {
                mesh: mesh,
                material: material,
                forceToBack: forceToBack,
                textured: textured,
                pools: [],
                triCounts: [],
                count: 0,
                totalVerts: 0,
                totalTris: 0,
                combinedVertexData: new Vector<Float>(),
                combinedIndexData: new Vector<Int>(),
                combinedUvtData: new Vector<Float>(),
                combinedDepthData: new Vector<Float>(),
            };
            bucketList.push(bucket);
        }

        // Register as active this frame (first time count goes from 0 to 1)
        if (bucket.count == 0) {
            if (_activeBatchBucketCount >= _activeBatchBuckets.length)
                _activeBatchBuckets.push(bucket);
            else
                _activeBatchBuckets[_activeBatchBucketCount] = bucket;
            _activeBatchBucketCount++;
        }

        // Add pool reference (index-based, using count as logical length)
        if (bucket.count >= bucket.pools.length) {
            bucket.pools.push(pool);
            bucket.triCounts.push(triCount);
        } else {
            bucket.pools[bucket.count] = pool;
            bucket.triCounts[bucket.count] = triCount;
        }
        bucket.count++;
        bucket.totalVerts += pool.usedVertexCount;
        bucket.totalTris += triCount;
    }

    // Reusable matrix for computing VP when no MVP is provided
    static var _vpMatrix:Matrix3D = new Matrix3D();

    public function drawMeshPair(meshArg:Mesh3DAndShaderPair, ?position:Position3D, ?mvpMatrix:Matrix3D):Void {
        Debugger.meshesRendered++;

        if (meshArg == null || meshArg.mesh == null || meshArg.mesh.vertexData == null || meshArg.mesh.indexData == null) return;

        final mesh = meshArg.mesh;
        final sw:Float = screenWidth;
        final sh:Float = screenHeight;

        final srcVerts:Vector<Float> = mesh.vertexData.vertices;
        final stride:Int = cast mesh.vertexData.stride;
        if (stride <= 0 || srcVerts == null || srcVerts.length == 0) return;

        final posOffset:Int = cast mesh.vertexData.attributes.pos3;
        final vertexCount:Int = Std.int(srcVerts.length / stride);
        if (vertexCount <= 0) return;

        final nearPlane:Float = _frameCamera.near;
        final eps:Float = 1e-6;

        // ---- pooled buffers (list per mesh, supports same mesh rendered multiple times per frame)
        var poolList = meshPoolLists.get(mesh);
        if (poolList == null) {
            poolList = [];
            meshPoolLists.set(mesh, poolList);
        }
        var poolIdx = meshPoolCounters.get(mesh) ?? 0;
        if (poolIdx == 0) {
            // First use this frame — track for reset (avoids ObjectMap.keys() iterator)
            if (_touchedMeshCount >= _touchedMeshes.length)
                _touchedMeshes.push(mesh);
            else
                _touchedMeshes[_touchedMeshCount] = mesh;
            _touchedMeshCount++;
        }
        var pool:MeshPoolBuffers;
        if (poolIdx < poolList.length) {
            pool = poolList[poolIdx];
        } else {
            pool = {
                vertexData: new Vector<Float>(),
                indexData: new Vector<Int>(),
                uvtData: new Vector<Float>(),
                depthData: new Vector<Float>(),
                viewX: new Vector<Float>(),
                viewY: new Vector<Float>(),
                viewZ: new Vector<Float>(),
                outcodes: new Vector<Int>(),
                lastCameraIter: -1,
                lastPositionIter: -1,
                lastTriCount: 0,
                lastMaterial: null,
                usedVertexCount: 0,
                usedTextured: false,
                forceToBack: false,
            };
            poolList.push(pool);
        }
        meshPoolCounters.set(mesh, poolIdx + 1);

        // ---- Build the combined MVP transform ----
        // If an MVP matrix was provided (from Entity3D), use it directly.
        // Otherwise compute VP from camera (+ optional position).
        // Uses copyRawDataTo() into a reusable buffer to avoid per-call rawData allocation on Flash.
        var mvpRaw:Vector<Float> = _mvpRawBuf;
        if (mvpMatrix != null) {
            mvpMatrix.copyRawDataTo(_mvpRawBuf);
        } else {
            _vpMatrix.identity();
            if (position != null) {
                position.updateMatrix();
                _vpMatrix.append(position);
            }
            _vpMatrix.append(_frameCamera.view);
            _vpMatrix.append(_frameCamera.projection);
            _vpMatrix.copyRawDataTo(_mvpRawBuf);
        }

        // ---- Object-level frustum culling (bounding sphere vs MVP frustum)
        if (mesh.boundingSphere == null && mesh.vertexData.vertices.length > 0) {
            mesh.boundingSphere = BoundingSphere.fromVertexData(
                mesh.vertexData.vertices,
                stride,
                posOffset
            );
        }
        if (mesh.boundingSphere != null) {
            _frustum.extractFromMVP(mvpRaw);
            final bs = mesh.boundingSphere;
            if (!_frustum.testSphere(bs.centerX, bs.centerY, bs.centerZ, bs.radius)) {
                Debugger.meshesCulled++;
                return;
            }
        }

        // ---- Check if we can skip re-projection (nothing moved)
        final camIter:Int = _frameCamera.updateItterations;
        // If MVP matrix is a Position3D, use its updateItterations (combines cam+entity)
        final posIter:Int = (mvpMatrix != null && Std.isOfType(mvpMatrix, Position3D))
            ? cast(mvpMatrix, Position3D).updateItterations
            : ((position != null) ? position.updateItterations : -1);

        if (pool.lastCameraIter == camIter && pool.lastPositionIter == posIter && pool.lastTriCount > 0) {
            // Nothing changed — reuse cached pool data
            final cachedForceToBack = mesh.renderAttributes != null && mesh.renderAttributes.forceToBack;
            if (shouldBatchPool(pool, pool.lastTriCount)) {
                collectBatchPool(mesh, pool, pool.lastMaterial, pool.lastTriCount, cachedForceToBack, pool.usedTextured);
            } else {
                var rp = acquireRenderPool();
                rp.vertexData = pool.vertexData;
                rp.indexData = pool.indexData;
                rp.uvtData = pool.uvtData;
                rp.viewZ = pool.viewZ;
                rp.depthData = pool.depthData;
                rp.material = pool.lastMaterial;
                rp.triCount = pool.lastTriCount;
                rp.forceToBack = cachedForceToBack;
                enqueueRenderPool(rp);
            }
            return;
        }

        var vertexData = pool.vertexData;
        final baseLen:Int = vertexCount * 2;
        if (vertexData.length < baseLen) vertexData.length = baseLen;

        var viewX = pool.viewX;
        var viewY = pool.viewY;
        var viewZ = pool.viewZ;
        var outcodes = pool.outcodes;
        viewX.length = vertexCount;
        viewY.length = vertexCount;
        viewZ.length = vertexCount;
        if (outcodes.length < vertexCount) outcodes.length = vertexCount;

        // ---- Find texture bitmap (cached per shader to avoid per-frame reflection)
        var bitmapData:BitmapData = null;
        if (meshArg.shader != null) {
            if (textureCache.exists(meshArg.shader)) {
                bitmapData = textureCache.get(meshArg.shader);
            } else {
                if (Std.isOfType(meshArg.shader, ShaderPipeline)) {
                    final pipeline:ShaderPipeline = cast meshArg.shader;
                    var parts = pipeline.parts;
                    var pi:Int = 0;
                    var pn:Int = (parts != null) ? parts.length : 0;
                    while (pi < pn) {
                        var p = parts[pi];
                        if (p != null && Std.isOfType(p, TextureShaderPart)) {
                            var tp:TextureShaderPart = cast p;
                            bitmapData = tp.bitmapData;
                            break;
                        }
                        pi++;
                    }
                }
                textureCache.set(meshArg.shader, bitmapData);
            }
        }

        // ---- UVT setup (only if we have both a bitmap AND UVs in the mesh)
        var uvOffset:Int = findUvOffset(mesh);
        var useTextured:Bool = (bitmapData != null && uvOffset >= 0);

        var uvtData:Vector<Float> = null;
        if (useTextured) {
            uvtData = pool.uvtData;

            var baseUvtLen:Int = vertexCount * 3;
            if (uvtData.length < baseUvtLen) uvtData.length = baseUvtLen;
        }

        // ---- Project every vertex using the combined MVP matrix.
        // viewX/viewY store clip-space cx/cy, viewZ stores clip.w (≈ viewZ for depth).
        var i:Int = 0;
        var out2:Int = 0;
        while (i < vertexCount) {
            final basePos:Int = i * stride + posOffset;

            final x:Float = srcVerts[basePos];
            final y:Float = srcVerts[basePos + 1];
            final z:Float = srcVerts[basePos + 2];

            // clip = MVP * [x,y,z,1]
            final cx:Float = mvpRaw[0] * x + mvpRaw[4] * y + mvpRaw[8]  * z + mvpRaw[12];
            final cy:Float = mvpRaw[1] * x + mvpRaw[5] * y + mvpRaw[9]  * z + mvpRaw[13];
            final cw:Float = mvpRaw[3] * x + mvpRaw[7] * y + mvpRaw[11] * z + mvpRaw[15];

            // Store clip-space coords for intersectVertex, cw for depth/clipping
            viewX[i] = cx;
            viewY[i] = cy;
            viewZ[i] = cw;

            // Compute per-vertex outcode for fast tri rejection/acceptance
            var oc:Int = 0;
            if (cw < nearPlane) oc |= CLIP_NEAR;
            if (cx < -cw) oc |= CLIP_LEFT;
            if (cx > cw)  oc |= CLIP_RIGHT;
            if (cy < -cw) oc |= CLIP_BOTTOM;
            if (cy > cw)  oc |= CLIP_TOP;
            outcodes[i] = oc;

            if (cw >= nearPlane - eps) {
                if (cw > eps) {
                    final invW:Float = 1.0 / cw;
                    final ndcX:Float = cx * invW;
                    final ndcY:Float = cy * invW;

                    vertexData[out2]     = (ndcX * 0.5 + 0.5) * sw;
                    vertexData[out2 + 1] = (1.0 - (ndcY * 0.5 + 0.5)) * sh;
                } else {
                    vertexData[out2]     = 0;
                    vertexData[out2 + 1] = 0;
                }
            } else {
                vertexData[out2]     = 0;
                vertexData[out2 + 1] = 0;
            }

            out2 += 2;
            i++;
        }

        // ---- build a clipped + culled index list
        final srcIdx = mesh.indexData.indices;
        if (srcIdx == null || srcIdx.length < 3) return;

        var indexData = pool.indexData;

        // Initial estimate; subdivideTri grows dynamically if needed
        final maxOut:Int = srcIdx.length * 4;
        if (indexData.length < maxOut) indexData.length = maxOut;

        cullingTris.length = 0;

        // Set up frame-local clip state for intersectVertex
        _nextVert = vertexCount;
        _clipViewX = viewX;
        _clipViewY = viewY;
        _clipViewZ = viewZ;
        _clipVertexData = vertexData;
        _clipUvtData = uvtData;
        _clipNear = nearPlane;
        _clipEps = eps;
        _clipSw = sw;
        _clipSh = sh;
        _clipUseTextured = useTextured;

        // Set up deferred UVT state
        _srcVerts = srcVerts;
        _uvStride = stride;
        _uvOffset = uvOffset;
        _baseVertexCount = vertexCount;
        if (useTextured) {
            if (_uvtComputed.length < vertexCount) _uvtComputed.length = vertexCount;
            var ci:Int = 0;
            while (ci < vertexCount) {
                _uvtComputed[ci] = false;
                ci++;
            }
        }

        var t:Int = 0;
        var w:Int = 0;

        while (t + 2 < srcIdx.length) {
            final i0:Int = cast srcIdx[t];
            final i1:Int = cast srcIdx[t + 1];
            final i2:Int = cast srcIdx[t + 2];

            // bounds safety
            if (i0 < 0 || i1 < 0 || i2 < 0 || i0 >= vertexCount || i1 >= vertexCount || i2 >= vertexCount) {
                cullingTris.push(Std.int(t / 3));
                t += 3;
                continue;
            }

            // ---- Outcode-based trivial reject/accept ----
            final oc0:Int = outcodes[i0];
            final oc1:Int = outcodes[i1];
            final oc2:Int = outcodes[i2];

            // Trivial reject: all 3 vertices outside the same plane
            if ((oc0 & oc1 & oc2) != 0) {
                cullingTris.push(Std.int(t / 3));
                t += 3;
                continue;
            }

            final orCodes:Int = oc0 | oc1 | oc2;

            // Trivial accept: all 3 vertices fully inside all planes
            if (orCodes == 0) {
                if (useTextured) { ensureUvt(i0); ensureUvt(i1); ensureUvt(i2); }
                w = subdivideTri(indexData, w, vertexData, i0, i1, i2, sw, sh, 0);
                t += 3;
                continue;
            }

            // Ensure UVT for all 3 source vertices before any clipping/subdivision
            if (useTextured) { ensureUvt(i0); ensureUvt(i1); ensureUvt(i2); }

            // Partial clip — check if near-plane clipping is needed
            if ((orCodes & CLIP_NEAR) != 0) {
                // Near-plane clipping path (existing logic)
                final in0:Bool = (oc0 & CLIP_NEAR) == 0;
                final in1:Bool = (oc1 & CLIP_NEAR) == 0;
                final in2:Bool = (oc2 & CLIP_NEAR) == 0;

                var insideCount:Int = 0;
                if (in0) insideCount++;
                if (in1) insideCount++;
                if (in2) insideCount++;

                if (insideCount == 0) {
                    cullingTris.push(Std.int(t / 3));
                    t += 3;
                    continue;
                }

                if (insideCount == 1) {
                    if (in0) {
                        final a = i0;
                        final b = intersectVertex(i0, i1);
                        final c = intersectVertex(i2, i0);
                        w = subdivideTri(indexData, w, vertexData, a, b, c, sw, sh, 0);
                    } else if (in1) {
                        final a = i1;
                        final b = intersectVertex(i1, i2);
                        final c = intersectVertex(i0, i1);
                        w = subdivideTri(indexData, w, vertexData, a, b, c, sw, sh, 0);
                    } else {
                        final a = i2;
                        final b = intersectVertex(i2, i0);
                        final c = intersectVertex(i1, i2);
                        w = subdivideTri(indexData, w, vertexData, a, b, c, sw, sh, 0);
                    }
                } else {
                    // insideCount == 2 => quad => 2 tris
                    if (!in0) {
                        final i20 = intersectVertex(i2, i0);
                        final i01 = intersectVertex(i0, i1);
                        w = subdivideTri(indexData, w, vertexData, i1, i2, i20, sw, sh, 0);
                        w = subdivideTri(indexData, w, vertexData, i1, i20, i01, sw, sh, 0);
                    } else if (!in1) {
                        final i01 = intersectVertex(i0, i1);
                        final i12 = intersectVertex(i1, i2);
                        w = subdivideTri(indexData, w, vertexData, i0, i01, i12, sw, sh, 0);
                        w = subdivideTri(indexData, w, vertexData, i0, i12, i2, sw, sh, 0);
                    } else {
                        final i12 = intersectVertex(i1, i2);
                        final i20 = intersectVertex(i2, i0);
                        w = subdivideTri(indexData, w, vertexData, i0, i1, i12, sw, sh, 0);
                        w = subdivideTri(indexData, w, vertexData, i0, i12, i20, sw, sh, 0);
                    }
                }
            } else {
                // In front of near plane but partially outside other planes.
                // subdivideTri's internal isOffscreen handles screen-space rejection.
                w = subdivideTri(indexData, w, vertexData, i0, i1, i2, sw, sh, 0);
            }

            t += 3;
        }

        indexData.length = w;

        // Make UVT length match the highest vertex index we emitted (safety)
        if (useTextured) {
            var usedUvtLen:Int = _nextVert * 3;
            if (uvtData.length < usedUvtLen) uvtData.length = usedUvtLen;
        }

        // ---- Compute per-triangle depth (average of 3 vertex viewZ values)
        final triCount:Int = Std.int(w / 3);
        var depthData = pool.depthData;
        if (depthData.length < triCount) depthData.length = triCount;

        var di:Int = 0;
        var ti:Int = 0;
        while (di < triCount) {
            depthData[di] = viewZ[indexData[ti]] + viewZ[indexData[ti + 1]] + viewZ[indexData[ti + 2]];
            di++;
            ti += 3;
        }

        // ---- record post-clip state for batching
        pool.usedVertexCount = _nextVert;
        pool.usedTextured = useTextured;
        pool.forceToBack = mesh.renderAttributes != null && mesh.renderAttributes.forceToBack;

        // ---- push to render queue (or collect for batching)
        if (triCount > 0) {
            final resolvedForceToBack = mesh.renderAttributes != null && mesh.renderAttributes.forceToBack;
            if (shouldBatchPool(pool, triCount)) {
                collectBatchPool(mesh, pool, useTextured ? bitmapData : null, triCount, resolvedForceToBack, useTextured);
            } else {
                var rp = acquireRenderPool();
                rp.vertexData = vertexData;
                rp.indexData = indexData;
                rp.uvtData = uvtData;
                rp.viewZ = viewZ;
                rp.depthData = depthData;
                rp.material = useTextured ? bitmapData : null;
                rp.triCount = triCount;
                rp.forceToBack = resolvedForceToBack;
                enqueueRenderPool(rp);
            }
        }

        // Store UVT back into pool if it was used (may have been resized)
        if (useTextured) pool.uvtData = uvtData;

        // Update cache validation state
        pool.lastCameraIter = camIter;
        pool.lastPositionIter = posIter;
        pool.lastTriCount = triCount;
        pool.lastMaterial = useTextured ? bitmapData : null;
    }

    public inline function drawMeshPairs(meshes:Vector<Mesh3DAndShaderPair>) {
        if (meshes == null) return;
        var i = 0;
        var n = meshes.length;
        while (i < n) {
            var m = meshes[i];
            if (m != null) drawMeshPair(m);
            i++;
        }
    }

    public function drawEntities(entity:IEntity3D) {
        if (entity == null) return;
        if (!entity.visible) return;

        if (Std.isOfType(entity, Entity3D)) {
            var e:Entity3D = cast entity;
            var i = 0;
            var n = (e.meshes != null) ? e.meshes.length : 0;
            while (i < n) {
                var pair = e.meshes[i];
                if (pair != null && pair.mesh != null) {
                    drawMeshPair(pair, entity.position);
                }
                i++;
            }
        }

        var c = 0;
        var cn = (entity.children != null) ? entity.children.length : 0;
        while (c < cn) {
            var child = entity.children[c];
            if (child != null) drawEntities(child);
            c++;
        }
    }

    // -------------------------------------------------
    // Heap helpers for O(T log P) k-way merge
    // -------------------------------------------------

    /** True if entry at index a should be extracted before entry at index b.
        Tie-break on poolIdx preserves the current linear-scan ordering:
        the original code uses `d > bestDepth` (not >=), so lower pool index wins on ties. */
    private inline function heapBetter(a:Int, b:Int):Bool {
        final da = _heapDepth[a];
        final db = _heapDepth[b];
        return (da > db) || (da == db && _heapPool[a] < _heapPool[b]);
    }

    /** Swap two heap entries. */
    private inline function heapSwap(a:Int, b:Int):Void {
        final tp = _heapPool[a]; _heapPool[a] = _heapPool[b]; _heapPool[b] = tp;
        final td = _heapDepth[a]; _heapDepth[a] = _heapDepth[b]; _heapDepth[b] = td;
    }

    /** Sift down from a given index. Used for both extract-max and bottom-up heapify. */
    private function heapSiftDownFrom(idx:Int):Void {
        final n = _heapSize;
        while (true) {
            var best = idx;
            final left = 2 * idx + 1;
            final right = left + 1;
            if (left < n && heapBetter(left, best)) best = left;
            if (right < n && heapBetter(right, best)) best = right;
            if (best == idx) break;
            heapSwap(idx, best);
            idx = best;
        }
    }

    /** Bottom-up heapify: O(P) construction instead of O(P log P) repeated sift-up. */
    private function heapBuild():Void {
        var i = (_heapSize >> 1) - 1;
        while (i >= 0) {
            heapSiftDownFrom(i);
            i--;
        }
    }

    // -------------------------------------------------
    // Heap-based k-way merge: O(T log P)
    // -------------------------------------------------

    private function drawPoolHeapMerge(poolCount:Int):Void {
        var batchPoolIdx:Int = -1;
        var batchLen:Int = 0;

        // Two-pass: forced pools first, then normal pools.
        // Removes the forceToBack branch from the hot comparison path.
        for (pass in 0...2) {
            final wantForced = (pass == 0);

            // Build heap from pools matching this pass — O(P)
            _heapSize = 0;
            if (_heapPool.length < poolCount) {
                _heapPool.length = poolCount;
                _heapDepth.length = poolCount;
            }

            var pi = 0;
            while (pi < poolCount) {
                final pool = renderQueue[pi];
                if (pool.forceToBack == wantForced && pool.triCount > 0) {
                    poolCursors[pi] = 0;
                    final triIdx = poolSortOrders[pi][0];

                    _heapPool[_heapSize] = pi;
                    _heapDepth[_heapSize] = pool.depthData[triIdx];
                    _heapSize++;
                }
                pi++;
            }

            // Bottom-up heapify: O(P)
            heapBuild();

            // Extract triangles in order
            while (_heapSize > 0) {
                final bestPool = _heapPool[0];
                final cursor = poolCursors[bestPool];
                final triIdx = poolSortOrders[bestPool][cursor];
                poolCursors[bestPool]++;

                // Flush batch on pool switch
                if (bestPool != batchPoolIdx) {
                    if (batchLen > 0) {
                        sortedIndices.length = batchLen;
                        queueBatchGraphicsData(renderQueue[batchPoolIdx], sortedIndices);
                    }
                    batchPoolIdx = bestPool;
                    batchLen = 0;
                }

                // Append triangle indices
                final pool = renderQueue[bestPool];
                final srcOff = triIdx * 3;
                if (sortedIndices.length < batchLen + 3) sortedIndices.length = batchLen + 3;
                sortedIndices[batchLen]     = pool.indexData[srcOff];
                sortedIndices[batchLen + 1] = pool.indexData[srcOff + 1];
                sortedIndices[batchLen + 2] = pool.indexData[srcOff + 2];
                batchLen += 3;

                // Advance heap: replace root with next tri from same pool, or shrink
                final nextCursor = poolCursors[bestPool];
                if (nextCursor < renderQueue[bestPool].triCount) {
                    final nextTriIdx = poolSortOrders[bestPool][nextCursor];
                    _heapDepth[0] = renderQueue[bestPool].depthData[nextTriIdx];
                    heapSiftDownFrom(0);
                } else {
                    // Pool exhausted — remove root by replacing with last element
                    _heapSize--;
                    if (_heapSize > 0) {
                        _heapPool[0] = _heapPool[_heapSize];
                        _heapDepth[0] = _heapDepth[_heapSize];
                        heapSiftDownFrom(0);
                    }
                }
            }
        }

        // Flush final batch
        if (batchLen > 0) {
            sortedIndices.length = batchLen;
            queueBatchGraphicsData(renderQueue[batchPoolIdx], sortedIndices);
        }
    }

    // -------------------------------------------------
    // Linear k-way merge (original): O(T * P)
    // -------------------------------------------------

    private function drawPoolLinearMerge(poolCount:Int):Void {
        if (poolCursors.length < poolCount) poolCursors.resize(poolCount);
        var pi = 0;
        while (pi < poolCount) {
            poolCursors[pi] = 0;
            pi++;
        }

        var batchPoolIdx:Int = -1;
        var batchLen:Int = 0;

        while (true) {
            var bestPool:Int = -1;
            var bestDepth:Float = -1e30;
            var bestForced:Bool = false;

            pi = 0;
            while (pi < poolCount) {
                final cursor = poolCursors[pi];
                if (cursor < renderQueue[pi].triCount) {
                    final forced = renderQueue[pi].forceToBack;
                    final triIdx = poolSortOrders[pi][cursor];
                    final d = renderQueue[pi].depthData[triIdx];

                    if (forced && !bestForced) {
                        bestDepth = d;
                        bestPool = pi;
                        bestForced = true;
                    } else if (forced == bestForced && d > bestDepth) {
                        bestDepth = d;
                        bestPool = pi;
                    }
                }
                pi++;
            }

            if (bestPool == -1) break;

            final triIdx = poolSortOrders[bestPool][poolCursors[bestPool]];
            poolCursors[bestPool]++;

            if (bestPool != batchPoolIdx) {
                if (batchLen > 0) {
                    sortedIndices.length = batchLen;
                    queueBatchGraphicsData(renderQueue[batchPoolIdx], sortedIndices);
                }
                batchPoolIdx = bestPool;
                batchLen = 0;
            }

            final pool = renderQueue[bestPool];
            final srcOff = triIdx * 3;
            if (sortedIndices.length < batchLen + 3) sortedIndices.length = batchLen + 3;
            sortedIndices[batchLen]     = pool.indexData[srcOff];
            sortedIndices[batchLen + 1] = pool.indexData[srcOff + 1];
            sortedIndices[batchLen + 2] = pool.indexData[srcOff + 2];
            batchLen += 3;
        }

        if (batchLen > 0) {
            sortedIndices.length = batchLen;
            queueBatchGraphicsData(renderQueue[batchPoolIdx], sortedIndices);
        }
    }

    // -------------------------------------------------
    // drawPool: per-pool sort + configurable merge
    // ---- Flush collected batch buckets into the render queue ----
    // Phase A (proof pass): counts what WOULD be batched but still enqueues individually.
    // Phase B: change the else branch to build combined RenderPools.
    private function flushCollectedBatches():Void {
        var totalCandidatePools:Int = 0;
        var totalBatchedBuckets:Int = 0;

        var bi:Int = 0;
        while (bi < _activeBatchBucketCount) {
            var bucket = _activeBatchBuckets[bi];
            totalCandidatePools += bucket.count;

            if (bucket.count < batchMinInstances) {
                // Not enough instances — enqueue each pool individually
                var pi:Int = 0;
                while (pi < bucket.count) {
                    var srcPool = bucket.pools[pi];
                    var srcTriCount = bucket.triCounts[pi];
                    var rp = acquireRenderPool();
                    rp.vertexData = srcPool.vertexData;
                    rp.indexData = srcPool.indexData;
                    rp.uvtData = srcPool.uvtData;
                    rp.viewZ = srcPool.viewZ;
                    rp.depthData = srcPool.depthData;
                    rp.material = bucket.material;
                    rp.triCount = srcTriCount;
                    rp.forceToBack = bucket.forceToBack;
                    enqueueRenderPool(rp);
                    pi++;
                }
            } else {
                // Batch: build one combined RenderPool from all instance pools
                totalBatchedBuckets++;
                var totalVerts = bucket.totalVerts;
                var totalTris = bucket.totalTris;
                var totalIndices = totalTris * 3;

                // Resize persistent combined vectors (grow only, never shrink)
                if (bucket.combinedVertexData.length < totalVerts * 2)
                    bucket.combinedVertexData.length = totalVerts * 2;
                if (bucket.combinedIndexData.length < totalIndices)
                    bucket.combinedIndexData.length = totalIndices;
                if (bucket.combinedDepthData.length < totalTris)
                    bucket.combinedDepthData.length = totalTris;
                if (bucket.textured && bucket.combinedUvtData.length < totalVerts * 3)
                    bucket.combinedUvtData.length = totalVerts * 3;

                var dstVertBase:Int = 0;
                var dstTriBase:Int = 0;
                var dstIdxBase:Int = 0;

                var pi:Int = 0;
                while (pi < bucket.count) {
                    var src = bucket.pools[pi];
                    var srcTriCount = bucket.triCounts[pi];
                    var srcVertCount = src.usedVertexCount;
                    var srcIdxCount = srcTriCount * 3;

                    // Copy vertex data (x, y screen coords — 2 floats per vertex)
                    var si:Int = 0;
                    var di:Int = dstVertBase * 2;
                    var svEnd:Int = srcVertCount * 2;
                    while (si < svEnd) {
                        bucket.combinedVertexData[di] = src.vertexData[si];
                        si++;
                        di++;
                    }

                    // Copy UVT data (u, v, t — 3 floats per vertex)
                    if (bucket.textured) {
                        si = 0;
                        di = dstVertBase * 3;
                        svEnd = srcVertCount * 3;
                        while (si < svEnd) {
                            bucket.combinedUvtData[di] = src.uvtData[si];
                            si++;
                            di++;
                        }
                    }

                    // Copy index data with vertex base offset
                    si = 0;
                    di = dstIdxBase;
                    while (si < srcIdxCount) {
                        bucket.combinedIndexData[di] = src.indexData[si] + dstVertBase;
                        si++;
                        di++;
                    }

                    // Copy depth data (1 float per triangle)
                    si = 0;
                    di = dstTriBase;
                    while (si < srcTriCount) {
                        bucket.combinedDepthData[di] = src.depthData[si];
                        si++;
                        di++;
                    }

                    dstVertBase += srcVertCount;
                    dstTriBase += srcTriCount;
                    dstIdxBase += srcIdxCount;
                    pi++;
                }

                // Enqueue the single combined pool
                var rp = acquireRenderPool();
                rp.vertexData = bucket.combinedVertexData;
                rp.indexData = bucket.combinedIndexData;
                rp.uvtData = bucket.textured ? bucket.combinedUvtData : null;
                rp.viewZ = bucket.combinedVertexData; // dummy — viewZ is never read by drawPool/merge/flush
                rp.depthData = bucket.combinedDepthData;
                rp.material = bucket.material;
                rp.triCount = totalTris;
                rp.forceToBack = bucket.forceToBack;
                enqueueRenderPool(rp);
            }

            // Reset bucket's per-frame state (keep combined vectors allocated for reuse)
            bucket.count = 0;
            bucket.totalVerts = 0;
            bucket.totalTris = 0;
            bi++;
        }

        // Update debug counters
        Debugger.softwareBatchCandidatePools = totalCandidatePools;
        Debugger.softwareBatchBuckets = totalBatchedBuckets;
        Debugger.softwarePoolsAfterBatch = renderQueueCount;

        // Reset active list counter (buckets stay in _batchBucketsByMesh for reuse next frame)
        _activeBatchBucketCount = 0;
    }

    // -------------------------------------------------

    private function acquireDrawCommand():DeferredDrawCommand {
        if (_drawCommandUsed < _drawCommandPool.length) {
            return _drawCommandPool[_drawCommandUsed++];
        }

        var indices = new Vector<Int>();
        var cmd:DeferredDrawCommand = {
            bitmapFill: new GraphicsBitmapFill(),
            solidFill: new GraphicsSolidFill(0xFF0000, 1.0),
            trianglePath: new GraphicsTrianglePath(null, indices, null),
            endFill: new GraphicsEndFill(),
            indices: indices,
        };

        _drawCommandPool.push(cmd);
        _drawCommandUsed++;
        return cmd;
    }

    private inline function pushGraphicsData(data:IGraphicsData):Void {
        if (_graphicsData.length <= _graphicsDataCount) _graphicsData.length = _graphicsDataCount + 1;
        _graphicsData[_graphicsDataCount] = data;
        _graphicsDataCount++;
    }

    private function queueBatchGraphicsData(pool:RenderPool, indices:Vector<Int>):Void {
        if (indices.length == 0) return;

        Debugger.trianglesRendered += cast(indices.length / 3);
        Debugger.softwareFlushCalls++;

        var cmd = acquireDrawCommand();

        // Copy only the merged triangle index run. Vertices/UVT can stay as shared references
        // to the per-pool buffers for this frame, but indices must be copied because
        // sortedIndices is a scratch vector that gets overwritten on the next batch.
        if (cmd.indices.length < indices.length) cmd.indices.length = indices.length;
        var i:Int = 0;
        while (i < indices.length) {
            cmd.indices[i] = indices[i];
            i++;
        }
        cmd.indices.length = indices.length;

        cmd.trianglePath.vertices = pool.vertexData;
        cmd.trianglePath.indices = cmd.indices;
        cmd.trianglePath.uvtData = (pool.material != null) ? pool.uvtData : null;

        if (pool.material != null) {
            cmd.bitmapFill.bitmapData = pool.material;
            cmd.bitmapFill.matrix = null;
            cmd.bitmapFill.repeat = true;
            cmd.bitmapFill.smooth = true;
            pushGraphicsData(cmd.bitmapFill);
        } else {
            cmd.solidFill.color = 0xFF0000;
            cmd.solidFill.alpha = 1.0;
            pushGraphicsData(cmd.solidFill);
        }

        pushGraphicsData(cmd.trianglePath);
        pushGraphicsData(cmd.endFill);
    }

    private function submitGraphicsData():Void {
        if (_graphicsDataCount == 0) return;
        _graphicsData.length = _graphicsDataCount;
        container.graphics.drawGraphicsData(_graphicsData);
    }

    public function drawPool() {
        final poolCount = renderQueueCount;
        if (poolCount == 0) return;

        // ---- Step 1: Sort each pool's triangles by depth independently ----
        // Ensure we have enough sort order arrays
        while (poolSortOrders.length < poolCount) poolSortOrders.push([]);

        var pi:Int = 0;
        while (pi < poolCount) {
            final pool = renderQueue[pi];
            final tc = pool.triCount;
            var order = poolSortOrders[pi];

            // Resize per-pool order buffer to exactly tc (must not be larger,
            // since Array.sort sorts the entire array and stale indices would be out of bounds)
            order.resize(tc);

            // Initialize identity permutation
            var j:Int = 0;
            while (j < tc) {
                order[j] = j;
                j++;
            }

            // Sort descending by depth (back-to-front) — reused comparator, no per-pool closure
            _sortDepthRef = pool.depthData;
            order.sort(_depthSortFn);

            pi++;
        }

        // ---- Step 2: K-way merge across all pools ----
        if (useHeapMerge) {
            drawPoolHeapMerge(poolCount);
        } else {
            drawPoolLinearMerge(poolCount);
        }
    }

    public function render(camera:Camera3D, entities:Array<IEntity3D>, options:RendererOptions) {
        _frameCamera = camera;
        if (options != null) {
            screenWidth = options.width;
            screenHeight = options.height;
        }
        container.graphics.clear();
        if (options != null) {
            final r:Int = Std.int(options.bgColorR * 255);
            final g:Int = Std.int(options.bgColorG * 255);
            final b:Int = Std.int(options.bgColorB * 255);
            container.graphics.beginFill((r << 16) | (g << 8) | b, 1.0);
        } else {
            container.graphics.beginFill(0x000000, 1.0);
        }
        container.graphics.drawRect(0, 0, screenWidth, screenHeight);
        container.graphics.endFill();
        renderQueueCount = 0;
        renderPoolUsed = 0;
        _graphicsDataCount = 0;
        _drawCommandUsed = 0;

        // Reset only touched meshes (no ObjectMap.keys() iterator allocation)
        var i:Int = 0;
        while (i < _touchedMeshCount) {
            meshPoolCounters.set(_touchedMeshes[i], 0);
            i++;
        }
        _touchedMeshCount = 0;

        // Go through the entity → shader → engine.drawMesh() flow
        // so MVP matrices and child transforms are computed properly
        if (entities != null) {
            for (e in entities) {
                if (e != null && e.visible) {
                    e.render(this, camera, null);
                }
            }
        }

        Debugger.softwarePoolsBeforeBatch = renderQueueCount;
        var batchStart = Debugger.getTime();
        flushCollectedBatches();
        Debugger.softwareBatchBuildTTR = Debugger.getTime() - batchStart;
        drawPool();
        submitGraphicsData();
    }
}
