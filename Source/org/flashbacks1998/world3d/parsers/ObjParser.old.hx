package org.flashbacks1998.world3d.parsers;

import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.Vector;
import org.flashbacks1998.world3d.entity.Entity3D;
import openfl.Assets;
import org.flashbacks1998.workers.Worker;
import StringTools;
import haxe.ds.StringMap;
import Std;

typedef WorkerStatus = { complete:Bool, data:Dynamic, percent:Float };

class ObjParser extends Worker {
    public static var CHUNK_SIZE(default, null) = 256;

    // Raw geometry pools (from "v", "vt", "vn")
    private var _points:Vector<Float>;
    private var _texCoords:Vector<Float>;
    private var _normals:Vector<Float>;

    // Lines and parsing position
    private var _lines:Array<String>;
    private var _currentOffset:Int;

    // Root entity and current working entity/group
    private var _rootEntity:Entity3D;
    private var _currentObjectEntity:Entity3D; // entity for current "o"
    private var _currentEntity:Entity3D;       // entity where faces are being appended (current group or object)

    // bookkeeping:
    // Map current object name -> map(groupName -> Entity3D)
    private var _groupsByObject:StringMap<StringMap<Entity3D>>;
    // list of entities created (useful for external traversal)
    private var _entities:Vector<Entity3D>;

    // Options - allow injection of asset loader etc (kept from your previous pattern)
    public function new(content:String) {
        // initialize raw buffers
        _points = new Vector<Float>();
        _texCoords = new Vector<Float>();
        _normals = new Vector<Float>();
        _lines = null;
        _currentOffset = 0;

        _entities = new Vector<Entity3D>();
        _groupsByObject = new StringMap();

        // Create a root container Entity3D (no meaningful mesh for root)
        // We create a trivial mesh for the root to avoid null-mesh issues downstream.
        // Consumers should inspect root.children to find actual object/group meshes.
        _rootEntity = new Entity3D({
            name: "root",
            mesh: new Mesh3D({
                vertexData: {
                    stride: 0,
                    attributes: { pos3: 0 },
                    vertices: new Vector<Float>()
                },
                indexData: { indices: new Vector<UInt>() }
            })
        });

        // create a default object (in case file has faces before any 'o')
        _currentObjectEntity = makeNewEntity("default");
        pushChildToRoot(_currentObjectEntity);

        _currentEntity = _currentObjectEntity;

        super(()-> parseContent(content));
    }

    /**
     * Helper: normalize a line and return array of non-empty tokens.
     */
    private inline function splitAndFilter(line:String):Array<String> {
        final lineNoTabs = StringTools.replace(line, "\t", " ");
        final tokensRaw = lineNoTabs.split(" ");
        final out = tokensRaw.filter(t -> t.length > 0);
        return out;
    }

    /**
     * Factory: create a new Entity3D wrapping a new Mesh3D with the "parser" vertex layout.
     * Adjust 'stride' and attribute layout here to match your renderer (11 in prior code).
     */
    private function makeNewEntity(name:String):Entity3D {
        var mesh = new Mesh3D({
            vertexData: {
                stride: 11, // pos(3) + uv(2) + normal(3) + rgb(3) = 11 floats
                attributes: { pos3: 0, uv2: 3, rgb3: 5, norm3: 8 },
                vertices: new Vector<Float>()
            },
            indexData: { indices: new Vector<UInt>() }
        });

        var e = new Entity3D({ name: name, mesh: mesh });
        // ensure children vector exists so consumers can traverse object->groups
        // If your Entity3D already manages children, replace with e.addChild(...) calls.
        try {
            // dynamic set so if Entity3D has children field, this won't break
            if (Reflect.hasField(e, "children") == false) {
                Reflect.setField(e, "children", new Vector<Entity3D>());
            }
        } catch (err:Dynamic) {
            // ignore if Reflect fails in your environment - still ok, we keep _entities vector
        }

        _entities.push(e);
        return e;
    }

    /**
     * Attach a child to root entity in a safe way (works whether Entity3D exposes .children or .addChild()).
     */
    private function pushChildToRoot(child:Entity3D):Void {
        // prefer .children vector if it exists
        if (Reflect.hasField(_rootEntity, "children")) {
            var ch = Reflect.field(_rootEntity, "children");
            // assume it's a Vector<Entity3D>
            ch.push(child);
        } else {
            // fallback: try addChild method
            if (Reflect.hasField(_rootEntity, "addChild")) {
                Reflect.callMethod(_rootEntity, Reflect.field(_rootEntity, "addChild"), [ child ]);
            } else {
                // last-resort: set a dynamic 'children' field
                Reflect.setField(_rootEntity, "children", new Vector<Entity3D>());
                Reflect.field(_rootEntity, "children").push(child);
            }
        }
    }

    /**
     * Helper - get or create group entity for the given objectName & groupName
     * Groups are created as children of the object entity.
     */
    private function getOrCreateGroup(objectEntity:Entity3D, objectName:String, groupName:String):Entity3D {
        var groups = _groupsByObject.get(objectName) ?? new StringMap<Entity3D>();
        if (_groupsByObject.exists(objectName) == false) {
            _groupsByObject.set(objectName, groups);
        }

        if (!groups.exists(groupName)) {
            var gEntity = makeNewEntity(groupName);
            // attach as child of the objectEntity
            if (Reflect.hasField(objectEntity, "children")) {
                Reflect.field(objectEntity, "children").push(gEntity);
            } else if (Reflect.hasField(objectEntity, "addChild")) {
                Reflect.callMethod(objectEntity, Reflect.field(objectEntity, "addChild"), [ gEntity ]);
            } else {
                // best effort set children
                Reflect.setField(objectEntity, "children", new Vector<Entity3D>());
                Reflect.field(objectEntity, "children").push(gEntity);
            }
            groups.set(groupName, gEntity);
        }

        return groups.get(groupName);
    }

    /**
     * Core parsing loop. This function is called inside Worker() closure and returns WorkerStatus.
     */
    private function parseContent(content:String):WorkerStatus {
        if (_lines == null) {
            _lines = content.split("\n");
        }

        var processed = 0;
        var chunkEnd = Math.min(_currentOffset + CHUNK_SIZE, _lines.length);

        while (_currentOffset < chunkEnd) {
            var raw = _lines[_currentOffset];
            var tokens = splitAndFilter(raw);

            if (tokens.length == 0) {
                _currentOffset++;
                continue;
            }

            switch (tokens[0]) {
                case "v":
                    // vertex position
                    if (tokens.length >= 4) {
                        _points.push(Std.parseFloat(tokens[1]));
                        _points.push(Std.parseFloat(tokens[2]));
                        _points.push(Std.parseFloat(tokens[3]));
                    }
                case "vt":
                    if (tokens.length >= 3) {
                        // invert v to match your earlier behavior
                        _texCoords.push(Std.parseFloat(tokens[1]));
                        _texCoords.push(1 - Std.parseFloat(tokens[2]));
                    }
                case "vn":
                    if (tokens.length >= 4) {
                        _normals.push(Std.parseFloat(tokens[1]));
                        _normals.push(Std.parseFloat(tokens[2]));
                        _normals.push(Std.parseFloat(tokens[3]));
                    }

                case "o":
                    // object declaration: create a new object entity and make it current
                    var objName = if (tokens.length > 1) tokens[1] else "unnamed";
                    var objEntity = makeNewEntity(objName);
                    pushChildToRoot(objEntity);
                    _currentObjectEntity = objEntity;
                    _currentEntity = objEntity;
                    // reset groups for the new object
                    _groupsByObject.set(objName, new StringMap<Entity3D>());
                
                case "g":
                    // group declaration: may list multiple group names
                    if (tokens.length <= 1) {
                        // `g` with no names clears active group (fall back to object)
                        _currentEntity = _currentObjectEntity;
                        break;
                    }

                    var groupNames = tokens.slice(1).filter(s -> s.length > 0);
                    // create or reuse groups under the current object
                    for (gn in groupNames) {
                        getOrCreateGroup(_currentObjectEntity, _currentObjectEntity != null ? (Reflect.field(_currentObjectEntity, "name") : "default") : "default", gn);
                    }
                    // set active to first group
                    var chosen = groupNames[0];
                    var objectName = Reflect.field(_currentObjectEntity, "name");
                    _currentEntity = getOrCreateGroup(_currentObjectEntity, objectName, chosen);

                case "f":
                    // face (may be n-gon). supports v, v/vt, v//vn, v/vt/vn
                    // tokens[1..] are vertex specs
                    var faceSpecs = tokens.slice(1).filter(t -> t.length > 0);
                    if (faceSpecs.length < 3) {
                        break; // not enough to form a face
                    }

                    // triangle-fan triangulation: [0, i, i+1]
                    for (var triI = 1; triI < faceSpecs.length - 1; triI++) {
                        var tri = [ faceSpecs[0], faceSpecs[triI], faceSpecs[triI + 1] ];

                        // use current mesh stride (do not hardcode)
                        var stride = _currentEntity.mesh.vertexData.stride;
                        var baseIdx:UInt = Std.int(_currentEntity.mesh.vertexData.vertices.length / stride);

                        // for each corner in the triangle
                        for (cornerSpec in tri) {
                            var parts = cornerSpec.split("/");
                            var vi = Std.parseInt(parts[0]) - 1;

                            var ti:Int = -1;
                            if (parts.length > 1 && parts[1] != "") ti = Std.parseInt(parts[1]) - 1;

                            var ni:Int = -1;
                            if (parts.length > 2 && parts[2] != "") ni = Std.parseInt(parts[2]) - 1;

                            // --- PUSH POSITION ---
                            _currentEntity.mesh.vertexData.vertices.push(_points[vi * 3 + 0]);
                            _currentEntity.mesh.vertexData.vertices.push(_points[vi * 3 + 1]);
                            _currentEntity.mesh.vertexData.vertices.push(_points[vi * 3 + 2]);

                            // --- PUSH UV ---
                            if (ti >= 0 && ti * 2 + 1 < _texCoords.length) {
                                _currentEntity.mesh.vertexData.vertices.push(_texCoords[ti * 2 + 0]);
                                _currentEntity.mesh.vertexData.vertices.push(_texCoords[ti * 2 + 1]);
                            } else {
                                _currentEntity.mesh.vertexData.vertices.push(0.0);
                                _currentEntity.mesh.vertexData.vertices.push(0.0);
                            }

                            // --- PUSH NORMAL ---
                            var nBase = ni * 3;
                            if (ni >= 0 && nBase + 2 < _normals.length) {
                                _currentEntity.mesh.vertexData.vertices.push(_normals[nBase + 0]);
                                _currentEntity.mesh.vertexData.vertices.push(_normals[nBase + 1]);
                                _currentEntity.mesh.vertexData.vertices.push(_normals[nBase + 2]);
                            } else {
                                // compute face normal fallback (use verts of triangle)
                                var parts0 = tri[0].split("/");
                                var parts1 = tri[1].split("/");
                                var parts2 = tri[2].split("/");

                                var vi0 = Std.parseInt(parts0[0]) - 1;
                                var vi1 = Std.parseInt(parts1[0]) - 1;
                                var vi2 = Std.parseInt(parts2[0]) - 1;

                                var p0x = _points[vi0 * 3 + 0];
                                var p0y = _points[vi0 * 3 + 1];
                                var p0z = _points[vi0 * 3 + 2];

                                var p1x = _points[vi1 * 3 + 0];
                                var p1y = _points[vi1 * 3 + 1];
                                var p1z = _points[vi1 * 3 + 2];

                                var p2x = _points[vi2 * 3 + 0];
                                var p2y = _points[vi2 * 3 + 1];
                                var p2z = _points[vi2 * 3 + 2];

                                var ex1 = p1x - p0x;
                                var ey1 = p1y - p0y;
                                var ez1 = p1z - p0z;

                                var ex2 = p2x - p0x;
                                var ey2 = p2y - p0y;
                                var ez2 = p2z - p0z;

                                var nx = ey1 * ez2 - ez1 * ey2;
                                var ny = ez1 * ex2 - ex1 * ez2;
                                var nz = ex1 * ey2 - ey1 * ex2;

                                var lenSq = nx * nx + ny * ny + nz * nz;
                                if (lenSq > 0) {
                                    var invLen = 1.0 / Math.sqrt(lenSq);
                                    _currentEntity.mesh.vertexData.vertices.push(nx * invLen);
                                    _currentEntity.mesh.vertexData.vertices.push(ny * invLen);
                                    _currentEntity.mesh.vertexData.vertices.push(nz * invLen);
                                } else {
                                    // degenerate -> arbitrary normal
                                    _currentEntity.mesh.vertexData.vertices.push(0.0);
                                    _currentEntity.mesh.vertexData.vertices.push(1.0);
                                    _currentEntity.mesh.vertexData.vertices.push(0.0);
                                }
                            }

                            // --- PUSH DIFFUSE (r,g,b) ---
                            _currentEntity.mesh.vertexData.vertices.push(1.0);
                            _currentEntity.mesh.vertexData.vertices.push(1.0);
                            _currentEntity.mesh.vertexData.vertices.push(1.0);
                        }

                        // push indices for this triangle
                        _currentEntity.mesh.indexData.indices.push(baseIdx);
                        _currentEntity.mesh.indexData.indices.push(baseIdx + 1);
                        _currentEntity.mesh.indexData.indices.push(baseIdx + 2);
                    }

                default:
                    // ignore other tokens for now (usemtl, s, mtllib, etc. can be handled later)
            }

            _currentOffset++;
            processed++;
        }

        // progress or completion
        if (_currentOffset >= _lines.length) {
            // optionally: attach list of all entities to root so caller can find them easily
            try {
                Reflect.setField(_rootEntity, "entities", _entities);
            } catch (err:Dynamic) {}
            return { complete: true, data: _rootEntity, percent: 100.0 };
        } else {
            var pct = (_currentOffset / _lines.length) * 100.0;
            return { complete: false, data: null, percent: pct };
        }
    }
}
