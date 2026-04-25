package org.flashbacks1998.world3d.parsers;

import haxe.crypto.Base64;
import org.flashbacks1998.debugger.Debugger;

import org.flashbacks1998.world3d.entity.IEntity3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.entity.Entity3DGroup; 
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.world3d.shader.MtlShader;

import haxe.Json;
import haxe.ds.StringMap;
import openfl.Assets;
import openfl.utils.ByteArray;
import openfl.utils.Endian;
import openfl.Vector;
import openfl.display.BitmapData;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;

// Simple material info struct
private typedef GltfMaterialInfo = {
    var colorR:Float;
    var colorG:Float;
    var colorB:Float;
    var bitmap:BitmapData;
}

/**
 * Very basic glTF 2.0 parser:
 *  - Reads buffers, bufferViews, accessors, meshes, materials, textures, images, nodes, scenes
 *  - Builds Mesh3D + MtlShader
 *  - Can build a full entity hierarchy via loadEntities()
 */
class GltfParser {

    // Raw glTF JSON object (Dynamic)
    private var _gltf:Dynamic;

    // Top-level arrays from glTF
    private var _buffers:Array<Dynamic>;
    private var _bufferViews:Array<Dynamic>;
    private var _accessors:Array<Dynamic>;
    private var _meshes:Array<Dynamic>;
    private var _materials:Array<Dynamic>;
    private var _textures:Array<Dynamic>;
    private var _images:Array<Dynamic>;
    private var _nodes:Array<Dynamic>;
    private var _scenes:Array<Dynamic>;

    // Binary data for each buffer index
    private var _bufferData:Array<ByteArray>;

    // Cached bitmaps per image index
    private var _imageBitmaps:Array<BitmapData>;

    // Path prefixes
    private var _binaryPathPrefix:String;
    private var _imagePathPrefix:String; 

    public function new(jsonText:String, ?options:{
        ?binaryPathPrefix:String,
        ?imagePathPrefix:String
    }) {
        Debugger.log("[GltfParser] Parsing JSON...");
        _gltf = Json.parse(jsonText);

        _buffers     = _gltf.buffers;
        _bufferViews = _gltf.bufferViews;
        _accessors   = _gltf.accessors;
        _meshes      = _gltf.meshes;
        _materials   = _gltf.materials;
        _textures    = _gltf.textures;
        _images      = _gltf.images;
        _nodes       = _gltf.nodes;
        _scenes      = _gltf.scenes;

        _binaryPathPrefix = options?.binaryPathPrefix ?? "assets/binaries/";
        _imagePathPrefix  = options?.imagePathPrefix  ?? "assets/textures/";

        _bufferData   = [];
        _imageBitmaps = [];

        Debugger.log("[GltfParser] Constructed",
            "buffers=",   _buffers   != null ? _buffers.length   : 0,
            "bufferViews=", _bufferViews != null ? _bufferViews.length : 0,
            "accessors=", _accessors != null ? _accessors.length : 0,
            "meshes=",    _meshes    != null ? _meshes.length    : 0,
            "materials=", _materials != null ? _materials.length : 0,
            "textures=",  _textures  != null ? _textures.length  : 0,
            "images=",    _images    != null ? _images.length    : 0,
            "nodes=",     _nodes     != null ? _nodes.length     : 0,
            "scenes=",    _scenes    != null ? _scenes.length    : 0
        );
    }

    // --------------------------------------------------------
    // PUBLIC: build entities from nodes (with hierarchy)
    // --------------------------------------------------------

    /**
     * Load entities from the glTF scene graph.
     *
     * - Finds root nodes (either from glTF `scene`/`scenes`, or nodes with no parent).
     * - For each root, recursively builds:
     *      * Entity3D (if node has mesh)
     *      * Entity3DGroup (if node has no mesh but has children)
     * - Each entity’s position is filled from glTF node transform:
     *      * node.matrix (16 floats, column-major)
     *      * OR TRS: translation, rotation(quat x,y,z,w), scale
     */
    public function loadEntities():Array<IEntity3D> {
        Debugger.log("[GltfParser] loadEntities() called");
        loadAllBuffers();

        var result = new Array<IEntity3D>();

        if (_nodes == null || _nodes.length == 0) {
            Debugger.log("[GltfParser] No nodes found; returning empty entity list.");
            return result;
        }

        var rootNodeIndices = getRootNodeIndices();
        Debugger.log("[GltfParser] Root node indices:", rootNodeIndices);

        for (idx in rootNodeIndices) {
            Debugger.log("[GltfParser] Building entity hierarchy for root node", idx);
            var ent = buildEntityHierarchyForNode(idx);
            if (ent != null) {
                Debugger.log("[GltfParser] Root entity built for node", idx, "->", Std.string(ent));
                result.push(ent);
            } else {
                Debugger.log("[GltfParser] Root node", idx, "produced no entity (null).");
            }
        }

        Debugger.log("[GltfParser] loadEntities() complete. Entity count=", result.length);
        return result;
    }

    // --------------------------------------------------------
    // (optional) old API for flat root entity
    // --------------------------------------------------------

    public function buildRootEntity():Entity3DGroup {
        Debugger.log("[GltfParser] buildRootEntity() called (flat mesh list)");
        var root = new Entity3DGroup({ name: "gltf-root" });

        loadAllBuffers();
        if (_meshes == null) {
            Debugger.log("[GltfParser] No meshes; returning empty root group.");
            return root;
        }

        for (mi in 0..._meshes.length) {
            var meshDef:Dynamic = _meshes[mi];
            if (meshDef == null) continue;

            Debugger.log("[GltfParser] Processing mesh", mi, "name=", meshDef.name);

            var primitives:Array<Dynamic> = meshDef.primitives;
            if (primitives == null) {
                Debugger.log("[GltfParser] Mesh", mi, "has no primitives, skipping.");
                continue;
            }

            for (pi in 0...primitives.length) {
                var prim:Dynamic = primitives[pi];
                if (prim == null) continue;

                Debugger.log("[GltfParser]  primitive", pi, "material=", Reflect.hasField(prim, "material") ? prim.material : -1);

                // Material info for this primitive
                var matIndex:Int = -1;
                if (Reflect.hasField(prim, "material")) {
                    matIndex = Std.int(Reflect.field(prim, "material"));
                }
                var matInfo = getMaterialInfo(matIndex);

                // Build Mesh3D
                var mesh3d = buildMeshFromPrimitive(prim, matInfo);
                if (mesh3d == null) {
                    Debugger.log("[GltfParser]   primitive", pi, "produced null Mesh3D; skipping.");
                    continue;
                }

                // MtlShader: if matInfo.bitmap == null, it will use default white texture
                var shader:IShader3D = cast new MtlShader({ bmpData: matInfo.bitmap });

                var pairs = new Vector<Mesh3DAndShaderPair>();
                pairs.push({ mesh: mesh3d, shader: shader });

                var entity = new Entity3D({ meshes: pairs });
                if (meshDef.name != null) entity.name = meshDef.name + "_p" + pi;

                Debugger.log("[GltfParser]   added entity for mesh", mi, "primitive", pi, "name=", entity.name);
                root.add(entity);
            }
        }

        Debugger.log("[GltfParser] buildRootEntity() completed.");
        return root;
    }

    // --------------------------------------------------------
    // Internal: root node detection
    // --------------------------------------------------------

    private function getRootNodeIndices():Array<Int> {
        var roots = new Array<Int>();
        Debugger.log("[GltfParser] getRootNodeIndices()...");

        // Prefer glTF "scene" / "scenes" if present
        if (_scenes != null && _scenes.length > 0) {
            var sceneIndex:Int = 0;
            if (Reflect.hasField(_gltf, "scene")) {
                sceneIndex = Std.int(_gltf.scene);
            }
            if (sceneIndex < 0 || sceneIndex >= _scenes.length) sceneIndex = 0;

            var scene:Dynamic = _scenes[sceneIndex];
            Debugger.log("[GltfParser] Using scene index", sceneIndex);

            if (scene != null && Reflect.hasField(scene, "nodes")) {
                var nodeArr:Array<Dynamic> = scene.nodes;
                if (nodeArr != null) {
                    for (n in nodeArr) {
                        roots.push(Std.int(n));
                    }
                    Debugger.log("[GltfParser] Root nodes from scene:", roots);
                    return roots;
                }
            }
        }

        // Fallback: nodes with no parent
        if (_nodes == null) {
            Debugger.log("[GltfParser] No nodes; no roots to compute.");
            return roots;
        }

        var count = _nodes.length;
        var hasParent = [for (_ in 0...count) false];

        for (i in 0...count) {
            var node:Dynamic = _nodes[i];
            if (node == null) continue;
            if (Reflect.hasField(node, "children") && node.children != null) {
                var ch:Array<Dynamic> = node.children;
                for (c in ch) {
                    var ci = Std.int(c);
                    if (ci >= 0 && ci < count) hasParent[ci] = true;
                }
            }
        }

        for (i in 0...count) {
            if (!hasParent[i]) roots.push(i);
        }

        Debugger.log("[GltfParser] Root nodes (no parent):", roots);
        return roots;
    }

    // --------------------------------------------------------
    // Internal: build entity hierarchy for a node
    // --------------------------------------------------------

    private function buildEntityHierarchyForNode(nodeIndex:Int):IEntity3D {
        if (_nodes == null || nodeIndex < 0 || nodeIndex >= _nodes.length) {
            Debugger.log("[GltfParser] buildEntityHierarchyForNode: invalid index", nodeIndex);
            return null;
        }
        var node:Dynamic = _nodes[nodeIndex];
        if (node == null) {
            Debugger.log("[GltfParser] buildEntityHierarchyForNode: node", nodeIndex, "is null");
            return null;
        }

        Debugger.log("[GltfParser] buildEntityHierarchyForNode index=", nodeIndex, "name=", node.name);

        // Local transform → Position3D
        var pos = buildPositionFromNode(node);
        Debugger.log("[GltfParser]  node", nodeIndex, "position=", pos.toString());

        // Children
        var childEntities = new Array<IEntity3D>();
        if (Reflect.hasField(node, "children") && node.children != null) {
            var ch:Array<Dynamic> = node.children;
            Debugger.log("[GltfParser]  node", nodeIndex, "has children:", ch);
            for (c in ch) {
                var ci = Std.int(c);
                var childEnt = buildEntityHierarchyForNode(ci);
                if (childEnt != null) childEntities.push(childEnt);
            }
        }

        // Mesh?
        var meshIndex:Int = -1;
        if (Reflect.hasField(node, "mesh")) {
            meshIndex = Std.int(node.mesh);
        }

        var hasMesh = (meshIndex >= 0 && _meshes != null && meshIndex < _meshes.length);

        Debugger.log("[GltfParser]  node", nodeIndex, "hasMesh=", hasMesh, "childCount=", childEntities.length);

        // If no mesh and no children-with-mesh → skip
        if (!hasMesh && childEntities.length == 0) {
            Debugger.log("[GltfParser]  node", nodeIndex, "has neither mesh nor children; skipping.");
            return null;
        }

        if (hasMesh) {
            // Build Mesh3D + MtlShader pairs for this mesh
            var pairs = buildMeshPairsForMeshIndex(meshIndex);
            if (pairs == null || pairs.length == 0) {
                Debugger.log("[GltfParser]  node", nodeIndex, "mesh", meshIndex, "produced no pairs.");
                // no primitives, but maybe children exist
                if (childEntities.length == 0) return null;
                var groupOnly = new Entity3DGroup({ 
                    name: node.name, 
                    childen: childEntities 
                });
                groupOnly.position = pos;
                return groupOnly;
            }

            var entity = new Entity3D({ meshes: pairs });
            entity.position = pos;
            if (Reflect.hasField(node, "name") && node.name != null)
                entity.name = node.name;
            entity.childen = childEntities;
            Debugger.log("[GltfParser]  node", nodeIndex, "-> Entity3D name=", entity.name, "children=", childEntities.length);
            return entity;
        } else {
            // Pure transform group
            var group = new Entity3DGroup({
                name: node.name,
                childen: childEntities
            });
            group.position = pos;
            Debugger.log("[GltfParser]  node", nodeIndex, "-> Entity3DGroup name=", group.name, "children=", childEntities.length);
            return group;
        }
    }

    private function buildMeshPairsForMeshIndex(meshIndex:Int):Vector<Mesh3DAndShaderPair> {
        if (_meshes == null || meshIndex < 0 || meshIndex >= _meshes.length) {
            Debugger.log("[GltfParser] buildMeshPairsForMeshIndex: invalid meshIndex", meshIndex);
            return null;
        }

        var meshDef:Dynamic = _meshes[meshIndex];
        if (meshDef == null || meshDef.primitives == null) {
            Debugger.log("[GltfParser] buildMeshPairsForMeshIndex: mesh", meshIndex, "has no primitives");
            return null;
        }

        var prims:Array<Dynamic> = meshDef.primitives;
        var pairs = new Vector<Mesh3DAndShaderPair>();

        Debugger.log("[GltfParser] buildMeshPairsForMeshIndex mesh=", meshIndex, "primitiveCount=", prims.length);

        for (pi in 0...prims.length) {
            var prim:Dynamic = prims[pi];
            if (prim == null) continue;

            var matIndex:Int = -1;
            if (Reflect.hasField(prim, "material")) {
                matIndex = Std.int(prim.material);
            }
            Debugger.log("[GltfParser]  primitive", pi, "materialIndex=", matIndex);

            var matInfo = getMaterialInfo(matIndex);

            var mesh3d = buildMeshFromPrimitive(prim, matInfo);
            if (mesh3d == null) {
                Debugger.log("[GltfParser]   primitive", pi, "returned null Mesh3D; skipping.");
                continue;
            }

            var shader:IShader3D = cast new MtlShader({ bmpData: matInfo.bitmap });
            Debugger.log("[GltfParser]   primitive", pi, "created Mesh3D + MtlShader");

            pairs.push({ mesh: mesh3d, shader: shader });
        }

        Debugger.log("[GltfParser] buildMeshPairsForMeshIndex mesh=", meshIndex, "pairsCount=", pairs.length);
        return pairs;
    }

    // --------------------------------------------------------
    // Internal: node → Position3D
    // --------------------------------------------------------

    /**
     * Build a Position3D from a glTF node.
     *
     * Supports:
     *  - node.matrix: 16 floats, column-major
     *  - node.translation: [x,y,z]
     *  - node.rotation: [x,y,z,w] quaternion
     *  - node.scale: [x,y,z]
     */
    private function buildPositionFromNode(node:Dynamic):Position3D {
        // 1) If matrix is given, use it directly
        if (Reflect.hasField(node, "matrix") && node.matrix != null) {
            var arr:Array<Dynamic> = node.matrix;
            Debugger.log("[GltfParser] buildPositionFromNode: using node.matrix, len=", arr != null ? arr.length : -1);
            if (arr != null && arr.length == 16) {
                var raw = new Vector<Float>();
                raw.length = 0;
                for (v in arr) {
                    raw.push(Std.parseFloat(Std.string(v)));
                }
                var m = new Matrix3D(raw);
                return Position3D.fromMatrix(m);
            }
        }

        Debugger.log("[GltfParser] buildPositionFromNode: using TRS");

        // 2) Otherwise, build from TRS
        var m2 = new Matrix3D();
        m2.identity();

        // scale
        if (Reflect.hasField(node, "scale") && node.scale != null) {
            var sArr:Array<Dynamic> = node.scale;
            Debugger.log("[GltfParser]  scale=", sArr);
            if (sArr.length >= 3) {
                var sx = Std.parseFloat(Std.string(sArr[0]));
                var sy = Std.parseFloat(Std.string(sArr[1]));
                var sz = Std.parseFloat(Std.string(sArr[2]));
                m2.appendScale(sx, sy, sz);
            }
        }

        // rotation (quaternion x,y,z,w)
        if (Reflect.hasField(node, "rotation") && node.rotation != null) {
            var qArr:Array<Dynamic> = node.rotation;
            Debugger.log("[GltfParser]  rotation(quat)=", qArr);
            if (qArr.length >= 4) {
                appendRotationFromQuaternion(m2,
                    Std.parseFloat(Std.string(qArr[0])),
                    Std.parseFloat(Std.string(qArr[1])),
                    Std.parseFloat(Std.string(qArr[2])),
                    Std.parseFloat(Std.string(qArr[3]))
                );
            }
        }

        // translation
        if (Reflect.hasField(node, "translation") && node.translation != null) {
            var tArr:Array<Dynamic> = node.translation;
            Debugger.log("[GltfParser]  translation=", tArr);
            if (tArr.length >= 3) {
                var tx = Std.parseFloat(Std.string(tArr[0]));
                var ty = Std.parseFloat(Std.string(tArr[1]));
                var tz = Std.parseFloat(Std.string(tArr[2]));
                m2.appendTranslation(tx, ty, tz);
            }
        }

        return Position3D.fromMatrix(m2);
    }

    /**
     * Append rotation described by glTF quaternion (x,y,z,w) to the matrix.
     * Converts quat -> axis/angle, then uses Matrix3D.appendRotation().
     */
    private function appendRotationFromQuaternion(m:Matrix3D, x:Float, y:Float, z:Float, w:Float):Void {
        Debugger.log("[GltfParser] appendRotationFromQuaternion quat=", x, y, z, w);

        // Normalize quaternion
        var len = Math.sqrt(x * x + y * y + z * z + w * w);
        if (len == 0) {
            Debugger.log("[GltfParser]  quaternion length=0, skipping rotation.");
            return;
        }
        x /= len; y /= len; z /= len; w /= len;

        // angle = 2 * acos(w)
        var angleRad = 2.0 * Math.acos(w);
        var sinHalf = Math.sqrt(1.0 - w * w);

        var axisX:Float;
        var axisY:Float;
        var axisZ:Float;

        // If angle is very small, axis is arbitrary
        if (sinHalf < 0.00001) {
            axisX = 1.0;
            axisY = 0.0;
            axisZ = 0.0;
        } else {
            axisX = x / sinHalf;
            axisY = y / sinHalf;
            axisZ = z / sinHalf;
        }

        var angleDeg = angleRad * 180.0 / Math.PI;
        Debugger.log("[GltfParser]  axis=", axisX, axisY, axisZ, "angleDeg=", angleDeg);

        var axis = new Vector3D(axisX, axisY, axisZ);
        m.appendRotation(angleDeg, axis);
    }

    // --------------------------------------------------------
    // Internal: buffer loading
    // --------------------------------------------------------


    private function loadAllBuffers():Void {
        if (_bufferData.length > 0) {
            Debugger.log("[GltfParser] Buffers already loaded; skipping.");
            return;
        }
        if (_buffers == null) {
            Debugger.log("[GltfParser] No buffers to load.");
            return;
        }

        Debugger.log("[GltfParser] Loading buffers, count=", _buffers.length);

        for (i in 0..._buffers.length) {
            var b:Dynamic = _buffers[i];
            var uri:String = b.uri;

            Debugger.log("[GltfParser]  buffer", i, "uri=", uri, "byteLength=", b.byteLength);

            if (uri == null) {
                Debugger.log("[GltfParser]   Buffer", i, "has no URI; GLB/embedded (chunk) buffers not supported yet.");
                _bufferData.push(null);
                continue;
            }

            // --- data:application/octet-stream;base64,... ---
            if (StringTools.startsWith(uri, "data:")) {
                Debugger.log("[GltfParser]   Buffer", i, "is data URI; attempting base64 decode.");

                var comma = uri.indexOf(",");
                if (comma == -1) {
                    Debugger.log("[GltfParser]   data URI missing comma; cannot parse:", uri);
                    _bufferData.push(null);
                    continue;
                }

                var meta = uri.substr(5, comma - 5);   // "application/octet-stream;base64"
                var b64  = uri.substr(comma + 1);

                Debugger.log("[GltfParser]   meta=", meta);

                try {
                    // 1) decode to haxe.io.Bytes
                    var bytes:haxe.io.Bytes = Base64.decode(b64);

                    // 2) wrap in ByteArray for OpenFL
                    var ba = ByteArray.fromBytes(bytes);
                    ba.endian = Endian.LITTLE_ENDIAN;
                    ba.position = 0;

                    _bufferData.push(ba);
                    Debugger.log("[GltfParser]   decoded base64 buffer", i, "length=", ba.length);
                } catch (e:Dynamic) {
                    Debugger.log("[GltfParser]   FAILED to decode base64 for buffer", i, "error=", e);
                    _bufferData.push(null);
                }

                continue;
            }

            // --- external .bin file on disk ---
            var path = _binaryPathPrefix + uri;
            Debugger.log("[GltfParser]   loading bytes from", path);
            var fileBytes = Assets.getBytes(path);
            if (fileBytes == null) {
                Debugger.log("[GltfParser]   FAILED to load buffer bytes:", path);
                _bufferData.push(null);
                continue;
            }

            var fileBa = ByteArray.fromBytes(fileBytes);
            fileBa.endian = Endian.LITTLE_ENDIAN;
            fileBa.position = 0;
            _bufferData.push(fileBa);

            Debugger.log("[GltfParser]   buffer", i, "loaded from file, size=", fileBytes.length);
        }
    }


    // --------------------------------------------------------
    // Internal: Material / Texture handling
    // --------------------------------------------------------

    private function getMaterialInfo(materialIndex:Int):GltfMaterialInfo {
        // Defaults: white color, no texture
        var colorR:Float = 1.0;
        var colorG:Float = 1.0;
        var colorB:Float = 1.0;
        var bmp:BitmapData = null;

        Debugger.log("[GltfParser] getMaterialInfo index=", materialIndex);

        if (_materials == null || materialIndex < 0 || materialIndex >= _materials.length) {
            Debugger.log("[GltfParser]  material index out of range or no materials; using defaults.");
            return { colorR: colorR, colorG: colorG, colorB: colorB, bitmap: bmp };
        }

        var matDef:Dynamic = _materials[materialIndex];

        // pbrMetallicRoughness.baseColorFactor (RGBA)
        if (Reflect.hasField(matDef, "pbrMetallicRoughness")) {
            var pbr:Dynamic = matDef.pbrMetallicRoughness;
            Debugger.log("[GltfParser]  pbrMetallicRoughness present for material", materialIndex);
            if (pbr != null) {
                if (Reflect.hasField(pbr, "baseColorFactor")) {
                    var arr:Array<Dynamic> = pbr.baseColorFactor;
                    Debugger.log("[GltfParser]   baseColorFactor=", arr);
                    if (arr != null && arr.length >= 3) {
                        colorR = Std.parseFloat(Std.string(arr[0]));
                        colorG = Std.parseFloat(Std.string(arr[1]));
                        colorB = Std.parseFloat(Std.string(arr[2]));
                    }
                }

                // baseColorTexture
                if (Reflect.hasField(pbr, "baseColorTexture")) {
                    var texInfo:Dynamic = pbr.baseColorTexture;
                    Debugger.log("[GltfParser]   baseColorTexture=", texInfo);
                    if (texInfo != null && Reflect.hasField(texInfo, "index")) {
                        var texIndex:Int = Std.int(texInfo.index);
                        bmp = loadBitmapForTexture(texIndex);
                    }
                }
            }
        }

        Debugger.log("[GltfParser]  material", materialIndex, "color=", colorR, colorG, colorB, "hasTexture=", bmp != null);
        return {
            colorR: colorR,
            colorG: colorG,
            colorB: colorB,
            bitmap: bmp
        };
    }

    private function loadBitmapForTexture(texIndex:Int):BitmapData {
        Debugger.log("[GltfParser] loadBitmapForTexture index=", texIndex);

        if (_textures == null || _images == null || texIndex < 0 || texIndex >= _textures.length) {
            Debugger.log("[GltfParser]  invalid texture index or no textures/images.");
            return null;
        }

        var texDef:Dynamic = _textures[texIndex];
        if (texDef == null || !Reflect.hasField(texDef, "source")) {
            Debugger.log("[GltfParser]  texture", texIndex, "has no 'source' field.");
            return null;
        }

        var imgIndex:Int = Std.int(texDef.source);
        if (imgIndex < 0 || imgIndex >= _images.length) {
            Debugger.log("[GltfParser]  texture", texIndex, "references invalid image index", imgIndex);
            return null;
        }

        // Cached?
        if (imgIndex < _imageBitmaps.length && _imageBitmaps[imgIndex] != null) {
            Debugger.log("[GltfParser]  returning cached bitmap for image", imgIndex);
            return _imageBitmaps[imgIndex];
        }

        var imgDef:Dynamic = _images[imgIndex];
        if (imgDef == null || !Reflect.hasField(imgDef, "uri")) {
            Debugger.log("[GltfParser]  image", imgIndex, "has no 'uri'.");
            return null;
        }

        var uri:String = imgDef.uri;
        if (uri == null || StringTools.startsWith(uri, "data:")) {
            Debugger.log("[GltfParser]  data: URI images not supported yet; image", imgIndex, "uri=", uri);
            return null;
        }

        var path = _imagePathPrefix + uri;
        Debugger.log("[GltfParser]  loading bitmap from", path);
        var bmp:BitmapData = null;
        try {
            bmp = Assets.getBitmapData(path);
            Debugger.log("[GltfParser]  bitmap loaded successfully for image", imgIndex);
        } catch (e:Dynamic) {
            Debugger.log("[GltfParser]  FAILED to load bitmap:", path, "error=", e);
            bmp = null;
        }

        // store in cache
        if (imgIndex >= _imageBitmaps.length) {
            _imageBitmaps.resize(imgIndex + 1);
        }
        _imageBitmaps[imgIndex] = bmp;

        return bmp;
    }

    // --------------------------------------------------------
    // Internal: Mesh building
    // --------------------------------------------------------

    // Normalize UVs into [0,1] using accessor min/max (or computed bounds)
    private function normalizeTexcoordsUsingAccessor(texAccessorIndex:Int, uvs:Vector<Float>):Void {
        if (uvs == null || uvs.length < 2) return;
        if (_accessors == null || texAccessorIndex < 0 || texAccessorIndex >= _accessors.length) {
            Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: invalid accessor index", texAccessorIndex);
            return;
        }

        var acc:Dynamic = _accessors[texAccessorIndex];

        var minArr:Array<Dynamic> = null;
        var maxArr:Array<Dynamic> = null;
        if (Reflect.hasField(acc, "min"))  minArr = acc.min;
        if (Reflect.hasField(acc, "max"))  maxArr = acc.max;

        var minU:Float;
        var minV:Float;
        var maxU:Float;
        var maxV:Float;

        // If accessor doesn't have min/max, compute from data
        if (minArr == null || maxArr == null || minArr.length < 2 || maxArr.length < 2) {
            minU = maxU = uvs[0];
            minV = maxV = uvs[1];

            var i = 2;
            while (i < uvs.length) {
                var u = uvs[i];
                var v = uvs[i + 1];

                if (u < minU) minU = u;
                if (u > maxU) maxU = u;
                if (v < minV) minV = v;
                if (v > maxV) maxV = v;

                i += 2;
            }
            Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: computed UV min/max from data:",
                "min=(", minU, ",", minV, ") max=(", maxU, ",", maxV, ")");
        } else {
            minU = Std.parseFloat(Std.string(minArr[0]));
            minV = Std.parseFloat(Std.string(minArr[1]));
            maxU = Std.parseFloat(Std.string(maxArr[0]));
            maxV = Std.parseFloat(Std.string(maxArr[1]));
            Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: accessor UV min/max:",
                "min=(", minU, ",", minV, ") max=(", maxU, ",", maxV, ")");
        }

        var rangeU = maxU - minU;
        var rangeV = maxV - minV;

        if (Math.abs(rangeU) < 1e-6 || Math.abs(rangeV) < 1e-6) {
            Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: zero UV range, skipping.");
            return;
        }

        // Only normalize if UVs actually go outside [0,1]
        if (minU >= 0.0 && maxU <= 1.0 && minV >= 0.0 && maxV <= 1.0) {
            Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: UVs already in [0,1], skipping.");
            return;
        }

        var j = 0;
        while (j < uvs.length) {
            var u0 = uvs[j];
            var v0 = uvs[j + 1];

            uvs[j]     = (u0 - minU) / rangeU;
            uvs[j + 1] = (v0 - minV) / rangeV;

            j += 2;
        }

        Debugger.log("[GltfParser] normalizeTexcoordsUsingAccessor: UVs normalized to [0,1]");
    }


    private function buildMeshFromPrimitive(prim:Dynamic, matInfo:GltfMaterialInfo):Mesh3D {
        if (prim == null) return null;

        var attrs:Dynamic = prim.attributes;
        if (attrs == null || !Reflect.hasField(attrs, "POSITION")) {
            Debugger.log("[GltfParser] buildMeshFromPrimitive: primitive has no POSITION attribute; skipping.");
            return null;
        }

        Debugger.log("[GltfParser] buildMeshFromPrimitive attrs=", attrs);

        // Positions
        var posAccessorIndex:Int = Std.int(Reflect.field(attrs, "POSITION"));
        Debugger.log("[GltfParser]  POSITION accessor index=", posAccessorIndex);
        var positions = readFloatAccessor(posAccessorIndex, 3);
        if (positions == null || positions.length == 0) {
            Debugger.log("[GltfParser]  Failed to read POSITION accessor", posAccessorIndex);
            return null;
        }

        // Texcoords (optional)
        var texAccessorIndex:Int = -1;
        var uvs:Vector<Float> = null;
        if (Reflect.hasField(attrs, "TEXCOORD_0")) {
            texAccessorIndex = Std.int(Reflect.field(attrs, "TEXCOORD_0"));
            Debugger.log("[GltfParser]  TEXCOORD_0 accessor index=", texAccessorIndex);
            uvs = readFloatAccessor(texAccessorIndex, 2);

            // Normalize UVs into [0,1] if needed, using accessor min/max (or computed bounds)
            if (uvs != null) {
                normalizeTexcoordsUsingAccessor(texAccessorIndex, uvs);
            }
        }

        var vertexCount = Std.int(positions.length / 3);
        Debugger.log("[GltfParser]  vertexCount=", vertexCount);

        // Create Mesh3D, using its default layout:
        // stride=8, attributes: pos3(0), uv2(3), kdrgb3(5)
        var mesh = new Mesh3D();
        var vd = mesh.vertexData;
        vd.vertices = new Vector<Float>(); // fresh vector

        var i = 0;
        while (i < vertexCount) {
            // Position
            vd.vertices.push(positions[i * 3 + 0]);
            vd.vertices.push(positions[i * 3 + 1]);
            vd.vertices.push(positions[i * 3 + 2]);

            // UV
            if (uvs != null && uvs.length >= (i + 1) * 2) {
                vd.vertices.push(uvs[i * 2 + 0]);
                vd.vertices.push(uvs[i * 2 + 1]);
            } else {
                vd.vertices.push(0.0);
                vd.vertices.push(0.0);
            }

            // Diffuse color: from material baseColorFactor
            vd.vertices.push(matInfo.colorR);
            vd.vertices.push(matInfo.colorG);
            vd.vertices.push(matInfo.colorB);

            i++;
        }

        Debugger.log("[GltfParser]  vertex array size=", vd.vertices.length);

        // Indices
        var indices:Vector<UInt>;
        if (Reflect.hasField(prim, "indices")) {
            var idxAccessorIndex:Int = Std.int(Reflect.field(prim, "indices"));
            Debugger.log("[GltfParser]  indices accessor index=", idxAccessorIndex);
            indices = readIndexAccessor(idxAccessorIndex);
        } else {
            // No index buffer = assume 0..vertexCount-1
            Debugger.log("[GltfParser]  primitive has no indices accessor; building 0..vertexCount-1");
            indices = new Vector<UInt>();
            var k = 0;
            while (k < vertexCount) {
                indices.push(k);
                k++;
            }
        }

        Debugger.log("[GltfParser]  index count=", indices != null ? indices.length : 0);

        mesh.indexData.indices = indices;
        return mesh;
    }


    // --------------------------------------------------------
    // Internal: Accessor reading
    // --------------------------------------------------------

    private static inline function numComponentsForType(type:String):Int {
        return switch (type) {
            case "SCALAR": 1;
            case "VEC2":   2;
            case "VEC3":   3;
            case "VEC4":   4;
            case "MAT2":   4;
            case "MAT3":   9;
            case "MAT4":   16;
            default:       1;
        }
    }

    private static inline function bytesPerComponent(componentType:Int):Int {
        return switch (componentType) {
            case 5120, 5121: 1; // BYTE, UNSIGNED_BYTE
            case 5122, 5123: 2; // SHORT, UNSIGNED_SHORT
            case 5125, 5126: 4; // UNSIGNED_INT, FLOAT
            default:           4;
        }
    }
 
    /**
     * Read a FLOAT accessor (e.g., POSITION, TEXCOORD_0) into a Vector<Float>.
     * Supports componentType = 5126 (FLOAT) and applies sparse accessors.
     */
    private function readFloatAccessor(accessorIndex:Int, expectedComponents:Int):Vector<Float> {
        Debugger.log("[GltfParser] readFloatAccessor index=", accessorIndex, "expectedComponents=", expectedComponents);

        if (_accessors == null || accessorIndex < 0 || accessorIndex >= _accessors.length) {
            Debugger.log("[GltfParser]  Invalid accessor index", accessorIndex);
            return null;
        }

        var acc:Dynamic = _accessors[accessorIndex];
        var compType:Int = acc.componentType;
        if (compType != 5126) {
            Debugger.log("[GltfParser]  Float accessor with non-FLOAT componentType", compType, "not supported.");
            return null;
        }

        var typeStr:String = acc.type;
        var compCount:Int = numComponentsForType(typeStr);
        if (expectedComponents > 0 && compCount != expectedComponents) {
            Debugger.log("[GltfParser]  Accessor", accessorIndex, "type=", typeStr, "compCount=", compCount, "expected=", expectedComponents);
        }

        var count:Int = acc.count;
        Debugger.log("[GltfParser]  count=", count, "type=", typeStr);

        // -----------------------------
        // 1) Read base data (if any)
        // -----------------------------

        var out = new Vector<Float>();
        out.length = 0;

        var hasBaseBufferView:Bool =
            Reflect.hasField(acc, "bufferView") && acc.bufferView != null;

        if (hasBaseBufferView) {
            var bvIndex:Int = acc.bufferView;
            var bv:Dynamic = _bufferViews[bvIndex];
            var bufIndex:Int = bv.buffer;
            var data:ByteArray = _bufferData[bufIndex];
            if (data == null) {
                Debugger.log("[GltfParser]  No binary data for buffer", bufIndex);
                return null;
            }

            var bufferByteOffset:Int   = bv.byteOffset   != null ? bv.byteOffset   : 0;
            var accessorByteOffset:Int = acc.byteOffset  != null ? acc.byteOffset  : 0;
            var baseOffset:Int = bufferByteOffset + accessorByteOffset;

            var bytesPerComp:Int = bytesPerComponent(compType);
            var stride:Int = bv.byteStride != null ? bv.byteStride : compCount * bytesPerComp;

            Debugger.log("[GltfParser]  BASE bufferView=", bvIndex,
                        "buffer=", bufIndex,
                        "bufferByteOffset=", bufferByteOffset,
                        "accessorByteOffset=", accessorByteOffset,
                        "baseOffset=", baseOffset,
                        "bytesPerComp=", bytesPerComp,
                        "stride=", stride);

            var i = 0;
            while (i < count) {
                var pos = baseOffset + i * stride;
                data.position = pos;
                var j = 0;
                while (j < compCount) {
                    out.push(data.readFloat());
                    j++;
                }
                i++;
            }
        } else {
            // No base bufferView: initialize with zeros (spec default)
            Debugger.log("[GltfParser]  Accessor has no base bufferView; initializing", count * compCount, "floats to 0.");
            var i = 0;
            while (i < count * compCount) {
                out.push(0.0);
                i++;
            }
        }

        // -----------------------------
        // 2) Apply sparse accessor data
        // -----------------------------

        if (Reflect.hasField(acc, "sparse") && acc.sparse != null) {
            var sparse:Dynamic = acc.sparse;
            var sparseCount:Int = sparse.count;
            Debugger.log("[GltfParser]  Applying sparse accessor: count=", sparseCount);

            // --- 2.1) Read sparse indices ---
            var idxInfo:Dynamic = sparse.indices;
            var idxBVIndex:Int = idxInfo.bufferView;
            var idxBV:Dynamic = _bufferViews[idxBVIndex];
            var idxBufIndex:Int = idxBV.buffer;
            var idxData:ByteArray = _bufferData[idxBufIndex];
            if (idxData == null) {
                Debugger.log("[GltfParser]  No binary data for sparse indices buffer", idxBufIndex);
                return out; // we still return base data
            }

            var idxCompType:Int = idxInfo.componentType;
            var idxBytesPer:Int = bytesPerComponent(idxCompType);
            var idxBufferByteOffset:Int   = idxBV.byteOffset   != null ? idxBV.byteOffset   : 0;
            var idxAccessorByteOffset:Int = idxInfo.byteOffset != null ? idxInfo.byteOffset : 0;
            var idxBaseOffset:Int = idxBufferByteOffset + idxAccessorByteOffset;
            var idxStride:Int = idxBV.byteStride != null ? idxBV.byteStride : idxBytesPer;

            Debugger.log("[GltfParser]   sparse.indices bufferView=", idxBVIndex,
                        "buffer=", idxBufIndex,
                        "bufferByteOffset=", idxBufferByteOffset,
                        "accessorByteOffset=", idxAccessorByteOffset,
                        "baseOffset=", idxBaseOffset,
                        "bytesPerComp=", idxBytesPer,
                        "stride=", idxStride,
                        "componentType=", idxCompType);

            var sparseIndices = new Vector<Int>();
            sparseIndices.length = 0;
            var si = 0;
            while (si < sparseCount) {
                var pos = idxBaseOffset + si * idxStride;
                idxData.position = pos;

                var iv:Int = 0;
                switch (idxCompType) {
                    case 5121: // UNSIGNED_BYTE
                        iv = idxData.readUnsignedByte();
                    case 5123: // UNSIGNED_SHORT
                        iv = idxData.readUnsignedShort();
                    case 5125: // UNSIGNED_INT
                        iv = idxData.readUnsignedInt();
                    default:
                        Debugger.log("[GltfParser]   Unsupported sparse index componentType", idxCompType);
                        iv = 0;
                }
                sparseIndices.push(iv);
                si++;
            }

            // --- 2.2) Read sparse values ---
            var valInfo:Dynamic = sparse.values;
            var valBVIndex:Int = valInfo.bufferView;
            var valBV:Dynamic = _bufferViews[valBVIndex];
            var valBufIndex:Int = valBV.buffer;
            var valData:ByteArray = _bufferData[valBufIndex];
            if (valData == null) {
                Debugger.log("[GltfParser]  No binary data for sparse values buffer", valBufIndex);
                return out;
            }

            var valBytesPer:Int = bytesPerComponent(compType); // same as accessor
            var valBufferByteOffset:Int   = valBV.byteOffset   != null ? valBV.byteOffset   : 0;
            var valAccessorByteOffset:Int = valInfo.byteOffset != null ? valInfo.byteOffset : 0;
            var valBaseOffset:Int = valBufferByteOffset + valAccessorByteOffset;
            // Spec says sparse values are tightly packed, but we also honor byteStride if present
            var valStride:Int = valBV.byteStride != null ? valBV.byteStride : compCount * valBytesPer;

            Debugger.log("[GltfParser]   sparse.values bufferView=", valBVIndex,
                        "buffer=", valBufIndex,
                        "bufferByteOffset=", valBufferByteOffset,
                        "accessorByteOffset=", valAccessorByteOffset,
                        "baseOffset=", valBaseOffset,
                        "bytesPerComp=", valBytesPer,
                        "stride=", valStride);

            var sparseValues = new Vector<Float>();
            sparseValues.length = 0;

            si = 0;
            while (si < sparseCount) {
                var posVal = valBaseOffset + si * valStride;
                valData.position = posVal;

                var cj = 0;
                while (cj < compCount) {
                    sparseValues.push(valData.readFloat());
                    cj++;
                }
                si++;
            }

            // --- 2.3) Patch base data with sparse overrides ---
            si = 0;
            while (si < sparseCount) {
                var dstIndex:Int = sparseIndices[si];
                if (dstIndex < 0 || dstIndex >= count) {
                    Debugger.log("[GltfParser]   sparse index out of range:", dstIndex, "/", count);
                    si++;
                    continue;
                }

                var baseIdx = dstIndex * compCount;
                var srcIdx  = si * compCount;

                var cj = 0;
                while (cj < compCount) {
                    out[baseIdx + cj] = sparseValues[srcIdx + cj];
                    cj++;
                }

                si++;
            }

            Debugger.log("[GltfParser]  Sparse accessor applied.");
        }

        return out;
    }


    /**
     * Read an index accessor into Vector<UInt>.
     * Supports UNSIGNED_BYTE (5121), UNSIGNED_SHORT (5123), UNSIGNED_INT (5125).
     * NOTE: Stage3D index buffers are typically 16-bit; UNSIGNED_INT may not be usable on all targets.
     */
    private function readIndexAccessor(accessorIndex:Int):Vector<UInt> {
        Debugger.log("[GltfParser] readIndexAccessor index=", accessorIndex);

        if (_accessors == null || accessorIndex < 0 || accessorIndex >= _accessors.length) {
            Debugger.log("[GltfParser]  Invalid index accessor index", accessorIndex);
            return null;
        }

        var acc:Dynamic = _accessors[accessorIndex];
        var compType:Int = acc.componentType;
        var typeStr:String = acc.type;
        if (typeStr != "SCALAR") {
            Debugger.log("[GltfParser]  Index accessor", accessorIndex, "is not SCALAR (type=", typeStr, ")");
        }

        var count:Int = acc.count;
        Debugger.log("[GltfParser]  count=", count, "componentType=", compType);

        var bvIndex:Int = acc.bufferView;
        var bv:Dynamic = _bufferViews[bvIndex];
        var bufIndex:Int = bv.buffer;
        var data:ByteArray = _bufferData[bufIndex];
        if (data == null) {
            Debugger.log("[GltfParser]  No binary data for buffer", bufIndex);
            return null;
        }

        var bufferByteOffset:Int   = bv.byteOffset   != null ? bv.byteOffset   : 0;
        var accessorByteOffset:Int = acc.byteOffset  != null ? acc.byteOffset  : 0;
        var baseOffset:Int = bufferByteOffset + accessorByteOffset;

        var bytesPerComp:Int = bytesPerComponent(compType);
        var stride:Int = bv.byteStride != null ? bv.byteStride : bytesPerComp;

        Debugger.log("[GltfParser]  bufferView=", bvIndex,
                     "buffer=", bufIndex,
                     "bufferByteOffset=", bufferByteOffset,
                     "accessorByteOffset=", accessorByteOffset,
                     "baseOffset=", baseOffset,
                     "bytesPerComp=", bytesPerComp,
                     "stride=", stride);

        var out = new Vector<UInt>();
        out.length = 0;

        var i = 0;
        while (i < count) {
            var pos = baseOffset + i * stride;
            data.position = pos;

            var v:UInt = 0;
            switch (compType) {
                case 5121: // UNSIGNED_BYTE
                    v = data.readUnsignedByte();
                case 5123: // UNSIGNED_SHORT
                    v = data.readUnsignedShort();
                case 5125: // UNSIGNED_INT
                    v = data.readUnsignedInt();
                default:
                    Debugger.log("[GltfParser]  Unsupported index componentType", compType, "(accessor", accessorIndex, ")");
            }

            out.push(v);
            i++;
        }

        Debugger.log("[GltfParser]  readIndexAccessor done. indexCount=", out.length);
        return out;
    }
}
