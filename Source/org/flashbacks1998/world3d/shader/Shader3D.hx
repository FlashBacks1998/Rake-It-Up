package org.flashbacks1998.world3d.shader;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.world3d.engine.IRendererEngine;
import openfl.display3D.textures.TextureBase;
import flash.utils.Object;
import openfl.display.BitmapData;
import org.flashbacks1998.world3d.shader.IShader.Shader3DPreviousContextState;
import openfl.Vector;
import openfl.display3D.textures.Texture;
import haxe.ds.StringMap;
import flash.display3D.Context3DProgramType;
import openfl.display3D.Context3DProgramFormat;
import openfl.utils.AGALMiniAssembler;
import flash.display3D.Program3D;
import haxe.ds.ObjectMap;
import haxe.ds.IntMap;
import openfl.geom.Matrix3D;
import org.flashbacks1998.world3d.geom.Mesh3D;
import openfl.display3D.Context3D;
import org.flashbacks1998.world3d.shader.IShader.IShader3D;

class Shader3D implements IShader3D {

    // cacheKey -> (context -> Program3D)
	private static var _cachedPrograms:StringMap<ObjectMap<Context3D, Program3D>> = new StringMap();
	// bitmapData -> (context -> Texture)
	private static var _cachedTextures:ObjectMap<BitmapData, ObjectMap<Context3D, Texture>> = new ObjectMap();

	/**
	 * Uploads or returns a cached Texture for the provided BitmapData/context.
	 */
	public static function uploadTexture(bitmapData:BitmapData, context:Context3D):Texture {
		if (bitmapData == null || context == null) throw "bitmapData and context must be non-null";

		// check cache
		final ctxMap = _cachedTextures.get(bitmapData);
		if (ctxMap != null) {
			final cachedTex = ctxMap.get(context);
			if (cachedTex != null) { 
				Debugger.log("returning cached texture");
				return cachedTex;
			}
		}

		// create & upload
		final tex:Texture = context.createTexture(bitmapData.width, bitmapData.height, openfl.display3D.Context3DTextureFormat.BGRA, false);
		tex.uploadFromBitmapData(bitmapData);

		// store in cache
		final newMap:ObjectMap<Context3D, Texture> = ctxMap ?? new ObjectMap();
		newMap.set(context, tex);
		_cachedTextures.set(bitmapData, newMap);

		Debugger.log("created and cached new texture");
		return tex;
	}

	/**
	 * Assembles AGAL and uploads or returns a cached Program3D.
	 * cacheKey is derived from the vertex+fragment strings. If you have
	 * extremely large shaders you may want to use a hash instead.
	 */
	public static function uploadAGAL(context:Context3D, vertexShader:String, fragmentShader:String):Program3D {
		if (context == null) throw "context must be non-null";

		final cacheKey = (vertexShader ?? "") + "|" + (fragmentShader ?? "");
		// fast cache lookup
		final progMap = _cachedPrograms.get(cacheKey);
		if (progMap != null) {
			final cachedProg = progMap.get(context);
			if (cachedProg != null) {
				Debugger.log("returning cached program");
				return cachedProg;
			}
		}

		// assemble vertex
		var vertexAssembler = new AGALMiniAssembler();
		try {
			Debugger.log("Vertex AGAL ", vertexShader);
			vertexAssembler.assemble(Context3DProgramType.VERTEX, vertexShader, 2);
			Debugger.log("Vertex AGAL assembled (len=" + (vertexShader != null ? vertexShader.length : 0) + ")");
		} catch (e:Dynamic) {
			Debugger.log("ERROR assembling vertex AGAL: " + Std.string(e));
			trace(vertexShader);
			throw(e);
		}

		// assemble fragment
		var fragmentAssembler = new AGALMiniAssembler();
		try {
			Debugger.log("Fragment AGAL ", fragmentShader);
			fragmentAssembler.assemble(Context3DProgramType.FRAGMENT, fragmentShader, 2);
			Debugger.log("Fragment AGAL assembled (len=" + (fragmentShader != null ? fragmentShader.length : 0) + ")");
		} catch (e:Dynamic) {
			Debugger.log("ERROR assembling fragment AGAL: " + Std.string(e));
			trace(fragmentShader);
			throw(e);
		}

		// create and upload program to GPU
		var program:Program3D = context.createProgram();
		try {
			program.upload(vertexAssembler.agalcode, fragmentAssembler.agalcode);
			Debugger.log("Program uploaded to GPU");
		} catch (e:Dynamic) {
			Debugger.log("ERROR uploading program to GPU: " + Std.string(e));
			// dispose program if it has a dispose method (best-effort)
			try {
				program.dispose();
			} catch (_:Dynamic) {}
			throw(e);
		}

		// cache program
		final store:ObjectMap<Context3D, Program3D> = progMap ?? new ObjectMap();
		store.set(context, program);
		_cachedPrograms.set(cacheKey, store);

		return program;
	}

    public function getProgram(engine:IRendererEngine):Program3D {
        return null;
    }

    public function upload(engine:IRendererEngine):Void {

    }

    public function render(engine:IRendererEngine, mesh:Mesh3D, ?matrix:Matrix3D, ?options: {
        ?backbufferWidth:UInt,
		?backbufferHeight:UInt,
		?previousContextState:Shader3DPreviousContextState,
        ?forceCleanup:Bool,
    }) {

    }

	public function dispose(engine:IRendererEngine) {

	}

	public static function disposeProgram(program:Program3D) {
		if (program != null) {
			try {
				program.dispose();
				for(i in _cachedPrograms.keys()) 
					if(_cachedPrograms.get(i) != null) 
						for(k in _cachedPrograms.get(i).keys()) 
							if(_cachedPrograms.get(i).get(k) == program)
								_cachedPrograms.get(i).remove(k);
			} catch (_:Dynamic) {}
		}
	}

	public static function clearCache(context:Context3D) {
		if (context == null) return;

		// --- Clear cached programs for this context ---
		var progKeysToRemove:Array<String> = [];
		for (cacheKey in _cachedPrograms.keys()) {
			var ctxMap = _cachedPrograms.get(cacheKey);
			if (ctxMap != null) {
				var prog = ctxMap.get(context);
				if (prog != null) {
					// best-effort dispose
					try {
						prog.dispose();
					} catch (_:Dynamic) {}
					ctxMap.remove(context);
				}

				// if no more contexts for this program, remove the cacheKey
				if (!ctxMap.iterator().hasNext()) {
					progKeysToRemove.push(cacheKey);
				}
			}
		}
		for (cacheKey in progKeysToRemove) {
			_cachedPrograms.remove(cacheKey);
		}

		// --- Clear cached textures for this context ---
		var texKeysToRemove:Array<BitmapData> = [];
		for (bitmapData in _cachedTextures.keys()) {
			var ctxMap = _cachedTextures.get(bitmapData);
			if (ctxMap != null) {
				var tex = ctxMap.get(context);
				if (tex != null) {
					// best-effort dispose
					try {
						tex.dispose();
					} catch (_:Dynamic) {}
					ctxMap.remove(context);
				}

				// if no more contexts for this bitmapData, remove from cache
				if (!ctxMap.iterator().hasNext()) {
					texKeysToRemove.push(bitmapData);
				}
			}
		}
		for (bitmapData in texKeysToRemove) {
			_cachedTextures.remove(bitmapData);
		}
 
	} 
}