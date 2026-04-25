package org.flashbacks1998.world3d.optimizers;

import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.geom.Position3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import org.flashbacks1998.world3d.entity.Entity3D;
import org.flashbacks1998.world3d.shader.parts.TextureShaderPart;
import org.flashbacks1998.world3d.shader.ShaderPipeline;
import haxe.ds.StringMap;
import haxe.ds.ObjectMap;
import openfl.display.BitmapData;
import openfl.display3D.textures.TextureBase;
import openfl.Vector;

class Entity3DOptimizer {

    public static function combineMesh3Ds(meshes:Vector<{pair: Mesh3DAndShaderPair, position:Position3D}>):Vector<Mesh3DAndShaderPair> {
        final newMeshes:Vector<Mesh3DAndShaderPair> = new Vector();
        final meshesNonCandidates:Vector<Mesh3DAndShaderPair> = new Vector();

        final meshesCanidates:StringMap<{
            bitmaps:Vector<BitmapData>,
            meshes:Vector<{pair: Mesh3DAndShaderPair, bmpd:BitmapData, position:Position3D}>
        }> = new StringMap();

        // ------------- group candidates -------------
        for (i in 0...meshes.length) {
            final m = meshes[i];
            if (m == null || m.pair == null || m.pair.mesh == null) continue;

            final srcMesh = m.pair.mesh;
            if (srcMesh.indexData == null || srcMesh.vertexData == null) continue;
            if (srcMesh.indexData.indices == null || srcMesh.vertexData.vertices == null) continue;

            if (srcMesh.indexData.indices.length == 0 || srcMesh.vertexData.vertices.length == 0) {
                // nothing to combine
                continue;
            }

            if (!Std.isOfType(m.pair.shader, ShaderPipeline)) {
                meshesNonCandidates.push(m.pair);
                continue;
            }

            final shader = cast(m.pair.shader, ShaderPipeline);
            var partStr = "";
            var bmpd:BitmapData = null;

            for (p in shader.parts) {
                partStr += Type.getClassName(Type.getClass(p)) + ",";
                if (Std.isOfType(p, TextureShaderPart)) {
                    bmpd = cast(p, TextureShaderPart).bitmapData;
                }
            }

            final canidates = meshesCanidates.get(partStr) ?? {
                bitmaps: new Vector(),
                meshes: new Vector()
            };

            canidates.meshes.push({pair: m.pair, bmpd: bmpd, position: m.position});

            // only store non-null bitmaps; dedupe by identity
            if (bmpd != null) {
                canidates.bitmaps.push(bmpd);
            }

            meshesCanidates.set(partStr, canidates);
        }

        for (m in meshesNonCandidates) newMeshes.push(m);

        // ------------- combine each group -------------
        for (group in meshesCanidates) {
            if (group.meshes == null || group.meshes.length == 0) continue;

            // Deduplicate bitmaps (packing duplicates can cause entry-map ambiguity)
            final unique = new Vector<BitmapData>();
            final seen = new ObjectMap<BitmapData, Bool>();
            for (i in 0...group.bitmaps.length) {
                final b = group.bitmaps[i];
                if (b != null && !seen.exists(b)) {
                    seen.set(b, true);
                    unique.push(b);
                }
            }

            // Build atlas (if no textures, atlas can be null)
            final bmpdsAtlas = (unique.length > 0) ? TextureOptimizer.packBitmapsIntoAltas(unique) : null;

            // Create shader: clone parts but replace texture part with atlas texture if present
            final shader:ShaderPipeline = new ShaderPipeline();
            final firstShader = cast(group.meshes[0].pair.shader, ShaderPipeline);
            for (p in firstShader.parts) {
                if (Std.isOfType(p, TextureShaderPart)) {
                    if (bmpdsAtlas != null) shader.parts.push(new TextureShaderPart(bmpdsAtlas.bitmapData));
                    else shader.parts.push(p); // no atlas, keep original texture part
                } else {
                    shader.parts.push(p);
                }
            }

            // Create new combined mesh
            final newMesh:Mesh3D = new Mesh3D();

            // IMPORTANT: lock the vertex layout based on the first valid source mesh
            var baseStride:Int = 0;
            var baseAttrs:Dynamic = null; // attributes struct (pos3/uv2/kdrgb3)
            var baseLayoutKey:String = null;

            // allocate fresh vectors (don’t rely on Mesh3D defaults)
            newMesh.vertexData.vertices = new Vector<Float>();
            newMesh.indexData.indices = new Vector<UInt>();

            // try to adopt layout from first mesh that validates
            for (i in 0...group.meshes.length) {
                final sm = group.meshes[i].pair.mesh;
                final vd = sm.vertexData;
                final stride = safeStride(vd);

                if (stride <= 0) continue;
                if (vd.vertices.length % stride != 0) continue;

                baseStride = stride;
                baseAttrs = vd.attributes;
                baseLayoutKey = layoutKey(vd);

                // propagate to new mesh so later code is coherent
                newMesh.vertexData.stride = baseStride;
                newMesh.vertexData.attributes = vd.attributes;
                break;
            }

            // If we cannot establish a valid layout, don’t combine this group
            if (baseStride <= 0 || baseAttrs == null) {
                // fallback: keep meshes as-is
                for (i in 0...group.meshes.length) {
                    newMeshes.push(group.meshes[i].pair);
                }
                continue;
            }

            // Combine meshes safely
            for (mi in 0...group.meshes.length) {
                final item = group.meshes[mi];
                final srcPair = item.pair;
                if (srcPair == null || srcPair.mesh == null) continue;

                final srcMesh = srcPair.mesh;
                final vd = srcMesh.vertexData;
                final id = srcMesh.indexData;

                if (vd == null || id == null || vd.vertices == null || id.indices == null) continue;

                // Layout guard: stride + attribute offsets must match
                final sStride = safeStride(vd);
                if (sStride != baseStride || layoutKey(vd) != baseLayoutKey) {
                    // Safeguard: skip mismatched mesh rather than corrupting the combined mesh
                    // You can also push it to newMeshes separately if you prefer.
                    continue;
                }

                if (vd.vertices.length == 0 || id.indices.length == 0) continue;
                if (vd.vertices.length % baseStride != 0) continue;

                final srcVertexCount:Int = Std.int(vd.vertices.length / baseStride);

                // Validate indices are within source vertex range
                if (!indicesValid(id.indices, srcVertexCount)) {
                    continue;
                }

                // Determine atlas uv remap (optional)
                var uvW:Float = 1.0;
                var uvH:Float = 1.0;
                var uvX:Float = 0.0;
                var uvY:Float = 0.0;

                if (bmpdsAtlas != null) {
                    var currbmpd:BitmapData = item.bmpd;

                    // If bmpd wasn’t cached on the group item, try to find it (fallback)
                    if (currbmpd == null && Std.isOfType(srcPair.shader, ShaderPipeline)) {
                        for (p in cast(srcPair.shader, ShaderPipeline).parts) {
                            if (Std.isOfType(p, TextureShaderPart)) {
                                currbmpd = cast(p, TextureShaderPart).bitmapData;
                                break;
                            }
                        }
                    }

                    if (currbmpd != null) {
                        final entry = bmpdsAtlas.entries.get(currbmpd);
                        if (entry != null && bmpdsAtlas.width > 0 && bmpdsAtlas.height > 0) {
                            uvW = entry.width  / bmpdsAtlas.width;
                            uvH = entry.height / bmpdsAtlas.height;
                            uvX = entry.x      / bmpdsAtlas.width;
                            uvY = entry.y      / bmpdsAtlas.height;
                        }
                    }
                }

                // Cache transform once per mesh (NOT per vertex)
                var doTransform = false;
                var m = null;
                if (item.position != null) {
                    item.position.updateMatrix();
                    m = item.position.rawData;
                    doTransform = (m != null && m.length >= 16);
                }

                final dstVerts = newMesh.vertexData.vertices;
                final dstIdx = newMesh.indexData.indices;

                final dstVertexOffset:Int = Std.int(dstVerts.length / baseStride);

                final attrs:Dynamic = baseAttrs;
                final posOff:Int = attrs.pos3;
                final uvOff:Int = attrs.uv2;

                // Vertex bounds guards
                if (posOff < 0 || posOff + 2 >= baseStride) continue;
                if (uvOff < 0 || uvOff + 1 >= baseStride) {
                    // UVs missing; we can still combine, just skip UV remap
                }

                // Append vertices (copy, then modify copy)
                for (vi in 0...srcVertexCount) {
                    final base = vi * baseStride;

                    // copy whole vertex
                    for (k in 0...baseStride) {
                        dstVerts.push(vd.vertices[base + k]);
                    }

                    final outBase = (dstVerts.length - baseStride);

                    // transform position
                    if (doTransform) {
                        final xI = outBase + posOff;
                        final yI = outBase + posOff + 1;
                        final zI = outBase + posOff + 2;

                        final vx = dstVerts[xI];
                        final vy = dstVerts[yI];
                        final vz = dstVerts[zI];

                        final tx = m[0] * vx + m[4] * vy + m[8]  * vz + m[12];
                        final ty = m[1] * vx + m[5] * vy + m[9]  * vz + m[13];
                        final tz = m[2] * vx + m[6] * vy + m[10] * vz + m[14];

                        dstVerts[xI] = tx;
                        dstVerts[yI] = ty;
                        dstVerts[zI] = tz;
                    }

                    // remap UV (only if uvOff is valid)
                    if (uvOff >= 0 && uvOff + 1 < baseStride) {
                        final uI = outBase + uvOff;
                        final vI = outBase + uvOff + 1;

                        dstVerts[uI] = dstVerts[uI] * uvW + uvX;
                        dstVerts[vI] = dstVerts[vI] * uvH + uvY;
                    }
                }

                // Append indices with offset (single pass, no post-fix)
                for (ii in 0...id.indices.length) {
                    final idx = id.indices[ii];
                    dstIdx.push(idx + dstVertexOffset);
                }
            }

            // Safeguard: don’t output empty combined mesh
            if (newMesh.vertexData.vertices.length == 0 || newMesh.indexData.indices.length == 0) {
                for (i in 0...group.meshes.length) newMeshes.push(group.meshes[i].pair);
                continue;
            }

            newMeshes.push({ mesh: newMesh, shader: shader });
        }

        return newMeshes;
    }

    // ------------------------------------------------------
    // Safeguard helpers
    // ------------------------------------------------------

    private static function safeStride(vd:Dynamic):Int {
        var s:Int = 0;
        try s = vd.stride catch (_:Dynamic) s = 0;
        if (s > 0) return s;

        // Fallback: compute stride from attribute offsets
        // Assumes attrs has pos3/uv2/kdrgb3 (as in your renderer)
        try {
            final a:Dynamic = vd.attributes;
            var max:Int = 0;
            max = cast Math.max(max, a.pos3 + 3);
            max = cast Math.max(max, a.uv2 + 2);
            max = cast Math.max(max, a.kdrgb3 + 3);
            return max;
        } catch (_:Dynamic) {}

        return 0;
    }

    private static function layoutKey(vd:Dynamic):String {
        // Layout identity string: stride + key attribute offsets
        final s = safeStride(vd);
        try {
            final a:Dynamic = vd.attributes;
            return s + "|p:" + a.pos3 + "|uv:" + a.uv2 + "|kd:" + a.kdrgb3;
        } catch (_:Dynamic) {
            return s + "|noattrs";
        }
    }

    private static function indicesValid(indices:Dynamic, vertexCount:Int):Bool {
        if (indices == null) return false;
        if (vertexCount <= 0) return false;

        final n:Int = indices.length;
        for (i in 0...n) {
            final idx:Int = indices[i];
            if (idx < 0 || idx >= vertexCount) {
                return false;
            }
        }
        return true;
    }

    // (your optimizeEntity3Ds unchanged)
    public static function optimizeEntity3Ds(entities:Vector<org.flashbacks1998.world3d.entity.IEntity3D>, ?options:{ ?combineEntity3DMeshes:Bool }):Vector<org.flashbacks1998.world3d.entity.IEntity3D> {
        final entitiesRet:Vector<org.flashbacks1998.world3d.entity.IEntity3D> = new Vector();

        if (options?.combineEntity3DMeshes == true) {
            var meshesToCombine:Vector<{pair: Mesh3DAndShaderPair, position:Position3D}> = new Vector();
            for (e in entities) {
                if (Std.isOfType(e, Entity3D)) {
                    var ent = cast(e, Entity3D);
                    for (m in ent.meshes) meshesToCombine.push({ pair: m, position: ent.position });
                } else {
                    entitiesRet.push(e);
                }
            }

            if (meshesToCombine.length > 0) {
                final combinedMeshes = combineMesh3Ds(meshesToCombine);
                entitiesRet.push(new Entity3D({ meshes: combinedMeshes }));
            }
            return entitiesRet;
        }

        for (e in entities) entitiesRet.push(e);
        return entitiesRet;
    }
}