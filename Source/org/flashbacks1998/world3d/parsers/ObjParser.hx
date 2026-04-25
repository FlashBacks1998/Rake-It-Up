package org.flashbacks1998.world3d.parsers;

import haxe.Exception;
import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import org.flashbacks1998.world3d.shader.MtlShader;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;
import org.flashbacks1998.world3d.shader.TextureShader;

import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.entity.IEntity3D;

import openfl.utils.Future;
import openfl.display.BitmapData;
import openfl.Assets;
import openfl.Vector;
import openfl.utils.ByteArray;
import openfl.utils.Endian;

import haxe.Json;
import haxe.ds.StringMap;
import haxe.ds.IntMap;

import org.flashbacks1998.workers.Worker;

// -----------------------------------------------------
// Small helper typedefs
// -----------------------------------------------------

typedef FaceTokenParts = {
    pos:Null<Int>,
    uv:Null<Int>,
    norm:Null<Int>
}

typedef MtlMaterial = {
    var Ns:Float;
    var Ka:Array<Float>;
    var Kd:Array<Float>;
    var Ks:Array<Float>;
    var Ke:Array<Float>;
    var Ni:Float;
    var d:Float;
    var illum:Int;

    @:optional var map_Kd:String;
    @:optional var map_Kd_bmpd:BitmapData;

    @:optional var map_Bump:String;
    @:optional var map_Bump_bmpd:BitmapData;
}

class ObjParser extends Worker {
    public static var CHUNK_SIZE = 256;

    // ---------- scene result ----------
    private var _entities:Vector<IEntity3D> = null;

    // Current object/group entity & current mesh
    private var _currentEntity:Entity3D = null;
    private var _currentMesh:Mesh3D = null;
    private var _currentMaterial:MtlMaterial;

    private var _currentOffset = 0;

    private var _points:Vector<Float>   = null;  // x,y,z triples
    private var _normals:Vector<Float>  = null;  // x,y,z triples
    private var _texCoords:Vector<Float> = null; // u,v pairs
    private var _lines:Array<String>    = null;
    private var _vertexMap:IntMap<Int>  = null;  // key = zero-based position index
    private var _mtlMap:StringMap<MtlMaterial> = null;
    private var _futures:Vector<Future<Any>> = null;

    private static var _bmpdCache:StringMap<BitmapData> = new StringMap();

    private static var _basicMaterial:MtlMaterial = {
        Ns: 32.0,
        Ka: [1.0, 1.0, 1.0],
        Kd: [1.0, 1.0, 1.0],
        Ks: [0.0, 0.0, 0.0],
        Ke: [0.0, 0.0, 0.0],
        Ni: 1.0,
        d: 1.0,
        illum: 2,
        map_Kd: null,
        map_Kd_bmpd: null,
        map_Bump: null,
        map_Bump_bmpd: null
    };

    // ---------- INLINE HELPERS ----------

    inline private function parseFaceTokenParts(token:String):FaceTokenParts {
        var parts = token.split("/");
        var pos:Null<Int> = null;
        var uv:Null<Int> = null;
        var norm:Null<Int> = null;

        if (parts.length > 0 && parts[0].length > 0) pos = Std.parseInt(parts[0]);
        if (parts.length > 1 && parts[1].length > 0) uv = Std.parseInt(parts[1]);
        if (parts.length > 2 && parts[2].length > 0) norm = Std.parseInt(parts[2]);

        return { pos: pos, uv: uv, norm: norm };
    }

    inline private function resolveObjVertexZeroBased(raw:Int):Int {
        var vertexCount = Std.int(_points.length / 3);
        var resolved = if (raw > 0) raw - 1 else vertexCount + raw;
        return (resolved >= 0 && resolved < vertexCount) ? resolved : -1;
    }

    inline private function baseFloatIndexForRaw(raw:Int):Int {
        var zb = resolveObjVertexZeroBased(raw);
        return zb == -1 ? -1 : zb * 3;
    }

    inline private function resolveObjTexcoordZeroBased(raw:Int):Int {
        var texCount = Std.int(_texCoords.length / 2);
        var resolved = if (raw > 0) raw - 1 else texCount + raw;
        return (resolved >= 0 && resolved < texCount) ? resolved : -1;
    }

    inline private function baseTexFloatIndexForRaw(raw:Int):Int {
        var zb = resolveObjTexcoordZeroBased(raw);
        return zb == -1 ? -1 : zb * 2;
    }

    inline private function resolveObjNormalZeroBased(raw:Int):Int {
        var normCount = Std.int(_normals.length / 3);
        var resolved = if (raw > 0) raw - 1 else normCount + raw;
        return (resolved >= 0 && resolved < normCount) ? resolved : -1;
    }

    inline private function baseNormFloatIndexForRaw(raw:Int):Int {
        var zb = resolveObjNormalZeroBased(raw);
        return zb == -1 ? -1 : zb * 3;
    }

    // ---------- entity / mesh helpers ----------

    /**
     * Start a brand-new top-level Entity3D for an `o` or `g` statement.
     * Faces that follow will belong to this entity.
     */
    inline private function beginNewEntity(name:String):Void {
        if (_entities == null) _entities.length = 0;
        var pairs = new Vector<Mesh3DAndShaderPair>();
        pairs.length = 0;

        _currentEntity = new Entity3D({ meshes: pairs });
        _currentEntity.name = name;
        _entities.push(_currentEntity);

        _currentMesh = null;
        _vertexMap = new IntMap();
        _currentMaterial = _basicMaterial;

        Debugger.log("ObjParser: new entity started:", name);
    }

    /**
     * Ensure we have some current entity. Used when faces / usemtl
     * appear before any explicit `o` / `g`.
     */
    inline private function ensureCurrentEntity(?name:String):Void {
        if (_currentEntity == null) {
            beginNewEntity(name);
        }
    }

    /**
     * Ensure there is a mesh in the current entity using the *current* material.
     * Used for faces when no `usemtl` was specified.
     */
    inline private function ensureMeshIfMissing():Void {
        if (_currentMesh != null) return;
        ensureCurrentEntity(null);

        _currentMesh = new Mesh3D({
            vertexData: {
                stride: 11,
                attributes: {
                    pos3:   0,
                    uv2:    3,
                    norm3:  5,
                    kdrgb3: 8
                },
                vertices: new Vector<Float>()
            },
            indexData: {
                indices: new Vector<UInt>()
            }
        });

        var shader:IShader3D = new MtlShader({ bmpData: _currentMaterial.map_Kd_bmpd });
        _currentEntity.meshes.push({ mesh: _currentMesh, shader: shader });
        _vertexMap = new IntMap();

        Debugger.log("ObjParser: default mesh created for current material (no explicit usemtl).");
    }

    /**
     * When `usemtl` is encountered, we start a new mesh for that material
     * in the current entity.
     */
    inline private function ensureNewMeshForUsemtl(name:String):Void {
        ensureCurrentEntity(null);

        // resolve material first
        _currentMaterial = _mtlMap.get(name) ?? _basicMaterial;

        // create a mesh with stride=11 layout: pos3 @0, uv2 @3, norm3 @5, kdrgb3 @8
        _currentMesh = new Mesh3D({
            vertexData: {
                stride: 11,
                attributes: {
                    pos3:   0,
                    uv2:    3,
                    norm3:  5,
                    kdrgb3: 8
                },
                vertices: new Vector<Float>()
            },
            indexData: {
                indices: new Vector<UInt>()
            }
        });

        // create shader with the material bitmap (may be null)
        var shader:IShader3D = new MtlShader({ bmpData: _currentMaterial.map_Kd_bmpd });

        _currentEntity.meshes.push({ mesh: _currentMesh, shader: shader });
        _vertexMap = new IntMap();

        Debugger.log("New mesh for material:", name, "hasTexture:", _currentMaterial.map_Kd != null);
    }

    /**
     * Create a vertex (position + uv + normal + Kd color) in the current mesh
     * if it doesn't exist yet.
     *
     * key     = zero-based position index (used for deduping)
     * basePos = float index into _points (x,y,z)
     * rawUv   = OBJ index for vt (may be null)
     * rawNorm = OBJ index for vn (may be null)
     */
    inline private function createOrGetVertexForPosition(
        key:Int,
        basePos:Int,
        rawUv:Null<Int>,
        rawNorm:Null<Int>
    ):Int {
        var existing:Null<Int> = _vertexMap.get(key);
        if (existing != null) return existing;

        var verts  = _currentMesh.vertexData.vertices;
        var stride = _currentMesh.vertexData.stride;
        var newVertexIndex = Std.int(verts.length / stride);

        // --- Position (pos3) ---
        verts.push(_points[basePos + 0]);
        verts.push(_points[basePos + 1]);
        verts.push(_points[basePos + 2]);

        // --- UV (uv2) ---
        if (rawUv != null) {
            var uvBase = baseTexFloatIndexForRaw(rawUv);
            if (uvBase != -1) {
                // note: original code flipped U
                verts.push(1 - _texCoords[uvBase + 0]);
                verts.push(_texCoords[uvBase + 1]);
            } else {
                verts.push(0.0);
                verts.push(0.0);
            }
        } else {
            verts.push(0.0);
            verts.push(0.0);
        }

        // --- Normal (norm3) ---
        if (rawNorm != null) {
            var nBase = baseNormFloatIndexForRaw(rawNorm);
            if (nBase != -1) {
                verts.push(_normals[nBase + 0]);
                verts.push(_normals[nBase + 1]);
                verts.push(_normals[nBase + 2]);
            } else {
                // fallback normal
                verts.push(0.0);
                verts.push(0.0);
                verts.push(1.0);
            }
        } else {
            // no normal supplied → default +Z
            verts.push(0.0);
            verts.push(0.0);
            verts.push(1.0);
        }

        // --- Diffuse color from material Kd (kdrgb3) ---
        verts.push(_currentMaterial.Kd[0]);
        verts.push(_currentMaterial.Kd[1]);
        verts.push(_currentMaterial.Kd[2]);

        _vertexMap.set(key, newVertexIndex);
        return newVertexIndex;
    }

    inline public static function splitAndFilter(line:String) {
        final lineNoTabs = StringTools.replace(line, "	", " ");
        final tokensRaw = lineNoTabs.split(" ");
        final tokens = tokensRaw.filter(t -> t.length > 0);
        return tokens;
    }

    // -----------------------------------------------------
    // MTL parsing
    // -----------------------------------------------------

    public static function parseMtlContent(content:String, ?options: {
        ?map:StringMap<MtlMaterial>
    }):StringMap<MtlMaterial> {
        var map = options?.map ?? new StringMap<MtlMaterial>();
        if (content == null) return map;

        content = StringTools.replace(content, "\r\n", "\n");
        content = StringTools.replace(content, "\r", "\n");
        var lines = content.split("\n");

        var currentName:String = null;
        var current:MtlMaterial = null;

        function parseRGB(tokens:Array<String>):Array<Float> {
            var out = [0.0, 0.0, 0.0];
            for (i in 1...Std.int(Math.min(cast tokens.length, cast 4))) {
                var f = Std.parseFloat(tokens[i]);
                if (!Math.isNaN(f)) out[i - 1] = f;
            }
            return out;
        }

        for (rawLine in lines) {
            var line = StringTools.trim(rawLine);
            if (line.length == 0) continue;
            if (line.charAt(0) == '#') continue;

            var tokens = line.split(" ");

            switch (tokens[0]) {
                case "newmtl":
                    if (currentName != null && current != null) {
                        map.set(currentName, current);
                    }
                    currentName = tokens.length > 1 ? tokens.slice(1).join(" ") : "unnamed";
                    current = {
                        Ns: 0.0,
                        Ka: [0.0, 0.0, 0.0],
                        Kd: [1.0, 1.0, 1.0],
                        Ks: [0.0, 0.0, 0.0],
                        Ke: [0.0, 0.0, 0.0],
                        Ni: 1.0,
                        d: 1.0,
                        illum: 2
                    };
                case "Ns":
                    if (current != null && tokens.length > 1) {
                        var v = Std.parseFloat(tokens[1]);
                        if (!Math.isNaN(v)) current.Ns = v;
                    }
                case "Ka":
                    if (current != null) current.Ka = parseRGB(tokens);
                case "Kd":
                    if (current != null) current.Kd = parseRGB(tokens);
                case "Ks":
                    if (current != null) current.Ks = parseRGB(tokens);
                case "Ke":
                    if (current != null) current.Ke = parseRGB(tokens);
                case "Ni":
                    if (current != null && tokens.length > 1) {
                        var v2 = Std.parseFloat(tokens[1]);
                        if (!Math.isNaN(v2)) current.Ni = v2;
                    }
                case "d":
                    if (current != null && tokens.length > 1) {
                        var v3 = Std.parseFloat(tokens[1]);
                        if (!Math.isNaN(v3)) current.d = v3;
                    }
                case "illum":
                    if (current != null && tokens.length > 1) {
                        var iv = Std.parseInt(tokens[1]);
                        if (iv != null) current.illum = iv;
                    }
                case "map_Kd":
                    if (current != null && tokens.length > 1) {
                        current.map_Kd = tokens.slice(1).join(" ");
                    }
                case "map_Bump":
                    if (current != null && tokens.length > 1) {
                        current.map_Bump = tokens.slice(1).join(" ");
                    }
                default:
            }
        }

        if (currentName != null && current != null) {
            map.set(currentName, current);
        }

        return map;
    }

    // -----------------------------------------------------
    // MAIN PARSING
    // -----------------------------------------------------

    public function parseContent(content:String, ?options: {
        ?loadBitmapData:(id:String, ?useCache:Bool) -> BitmapData,
        ?loadMaterialFile:(id:String) -> String
    }):WorkerStatus {
        final getBitmapData = options?.loadBitmapData ??
            (id:String, ?useCache:Null<Bool>) -> {
                final fullId = "assets/textures/" + id;
                final cache = _bmpdCache.get(fullId);
                if (cache != null) return cache;

                var bmpd:BitmapData = null;
                try{
                    bmpd = Assets.getBitmapData(fullId, useCache);
                    _bmpdCache.set(fullId, bmpd);
                } catch (e:Exception){
                    Debugger.error("Failed to load " + fullId + " relying on fallback...");
                    bmpd = TextureShaderPart.getDefaultBitmapData();
                    _bmpdCache.set(fullId, bmpd);
                }

                return bmpd;
            }

        final getMaterialFile = options?.loadMaterialFile ??
            (id:String) -> Assets.getText("assets/objects/" + id);

        if (_lines == null) _lines = content.split("\n");

        var i = 0;
        while (i < CHUNK_SIZE && _currentOffset < _lines.length) {
            final tokens = splitAndFilter(_lines[_currentOffset]);
            if (tokens.length == 0) {
                i++;
                _currentOffset++;
                continue;
            }

            switch (tokens[0]) {
                case "mtllib":
                    final mtlContent = getMaterialFile(tokens[1]);
                    parseMtlContent(mtlContent, { map: _mtlMap });

                    for (m in _mtlMap) {
                        if (m.map_Kd != null && m.map_Kd_bmpd == null) {
                            Debugger.log("Getting bmpd", m.map_Kd);
                            m.map_Kd_bmpd = getBitmapData(m.map_Kd);
                            Debugger.log("Get bmpd", m.map_Kd, m.map_Kd_bmpd);
                        }
                    }

                case "usemtl":
                    ensureNewMeshForUsemtl(tokens[1]);

                // ---------- object / group ----------
                case "o":
                    var objName = tokens.length > 1 ? tokens.slice(1).join(" ") : null;
                    beginNewEntity(objName);

                case "g":
                    var grpName = tokens.length > 1 ? tokens.slice(1).join(" ") : null;
                    beginNewEntity(grpName);

                case "v":
                    _points.push(Std.parseFloat(tokens[1]));
                    _points.push(Std.parseFloat(tokens[2]));
                    _points.push(Std.parseFloat(tokens[3]));

                case "vt":
                    _texCoords.push(Std.parseFloat(tokens[1]));
                    _texCoords.push(1-Std.parseFloat(tokens[2]));

                case "vn":
                    _normals.push(Std.parseFloat(tokens[1]));
                    _normals.push(Std.parseFloat(tokens[2]));
                    _normals.push(Std.parseFloat(tokens[3]));

                case "f":
                    // make sure we have something to write into
                    ensureCurrentEntity(null);
                    ensureMeshIfMissing();

                    var faceSpecs = tokens.slice(1).filter(t -> t.length > 0);
                    if (faceSpecs.length < 3) break;

                    var p0 = parseFaceTokenParts(faceSpecs[0]);
                    if (p0.pos == null) break;

                    var base0 = baseFloatIndexForRaw(p0.pos);
                    var key0  = resolveObjVertexZeroBased(p0.pos);
                    if (base0 == -1 || key0 == -1) break;

                    // fan triangulation: (0, i, i+1)
                    for (iFace in 1...faceSpecs.length - 0 - 1) {
                        var p1 = parseFaceTokenParts(faceSpecs[iFace]);
                        var p2 = parseFaceTokenParts(faceSpecs[iFace + 1]);

                        if (p1.pos == null || p2.pos == null) continue;

                        var base1 = baseFloatIndexForRaw(p1.pos);
                        var base2 = baseFloatIndexForRaw(p2.pos);
                        var key1  = resolveObjVertexZeroBased(p1.pos);
                        var key2  = resolveObjVertexZeroBased(p2.pos);

                        if (base1 == -1 || base2 == -1 || key1 == -1 || key2 == -1) continue;

                        var vi0 = createOrGetVertexForPosition(key0, base0, p0.uv, p0.norm);
                        var vi1 = createOrGetVertexForPosition(key1, base1, p1.uv, p1.norm);
                        var vi2 = createOrGetVertexForPosition(key2, base2, p2.uv, p2.norm);

                        _currentMesh.indexData.indices.push(Std.int(vi0));
                        _currentMesh.indexData.indices.push(Std.int(vi1));
                        _currentMesh.indexData.indices.push(Std.int(vi2));
                    }
            }

            i++;
            _currentOffset++;
        }

        if (_currentOffset >= _lines.length) {
            // ---------- done: return array of entities ----------
            return { complete: true, data: _entities };
        } else {
            return { complete: false, percent: (_currentOffset / _lines.length) * 100 };
        }
    }

    // -----------------------------------------------------
    // CONSTRUCTOR
    // -----------------------------------------------------

    public function new(content:String) {
        _entities = new Vector();
        _currentEntity = null;
        _currentMesh = null;
        _currentMaterial = _basicMaterial;

        _currentOffset = 0;
        _points = new Vector<Float>();
        _normals = new Vector<Float>();
        _texCoords = new Vector<Float>();
        _lines = null;
        _vertexMap = new IntMap();
        _mtlMap = new StringMap();
        _futures = new Vector();

        super(() -> parseContent(content));
    }
}
