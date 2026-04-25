package org.flashbacks1998.world3d.optimizers;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.algorithms.sorting.BinaryTree;
import haxe.ds.ObjectMap;
import openfl.display.BitmapData;
import openfl.geom.Rectangle;
import openfl.geom.Point;
import openfl.Vector;
import Math;

typedef TextureOptimizerPackedAtlasEntry = {
	bitmapData:BitmapData,
	width:Int,
	height:Int,
	x:Int,
	y:Int,
}

typedef TextureOptimizerPackedAtlas = {
	bitmapData:BitmapData,
	width:Int,
	height:Int,
	entries:ObjectMap<BitmapData, TextureOptimizerPackedAtlasEntry>,
}

class TextureOptimizer {

	public static function packBitmapsIntoAltas(bmpds:Vector<BitmapData>, ?maxWidth:Int = 1024*2, ?maxHeight:Int = 1024*2, ?padding:Int = 0, ?sortByLargest:Bool = true):TextureOptimizerPackedAtlas {
		if (bmpds == null || bmpds.length == 0) return null;

		// Build rectangles array { bitmap, w, h, origW, origH }
		var rects = new Array<Dynamic>();
		var totalArea:Float = 0;
		for (b in bmpds) {
			var origW = Std.int(b.width);
			var origH = Std.int(b.height);
			var w = origW + padding * 2;
			var h = origH + padding * 2;
			// if any single image exceeds maxWidth/maxHeight, it will make packing fail for some sizes;
			// we still include them so the algorithm will either choose a bigger pow2 or fail.
			Debugger.log("bmpd to opt", w, h, b);
			rects.push({ bitmap: b, w: w, h: h, origW: origW, origH: origH });
			totalArea += w * h;
		}

		if (sortByLargest) {
			rects.sort(function(a, b) return Std.int(Math.max(b.w, b.h) - Math.max(a.w, a.h)));
		}

		// helper: list powers of two up to limit
		var pow2 = function(limit:Int):Array<Int> {
			var out = new Array<Int>();
			var v = 1;
			while (v <= limit) {
				out.push(v);
				v <<= 1;
			}
			return out;
		}

		var widths = pow2(maxWidth);
		var heights = pow2(maxHeight);

		// Build candidate atlas sizes (prefer those with area >= totalArea)
		var candidates = new Array<{w:Int,h:Int}>();
		for (w in widths) for (h in heights) {
			if (w * h >= Std.int(totalArea)) candidates.push({ w:w, h:h });
		}

		// If none had enough area to pass the quick area test, try all combinations anyway
		if (candidates.length == 0) {
			for (w in widths) for (h in heights) candidates.push({ w:w, h:h });
		}

		// Sort candidates by area (ascending), then by perimeter (ascending)
		candidates.sort(function(a,b) {
			var aa = a.w * a.h;
			var bb = b.w * b.h;
			if (aa != bb) return aa - bb;
			return (a.w + a.h) - (b.w + b.h);
		});

		// Try each candidate using BinaryTree packer
		for (c in candidates) {
			var packer = new BinaryTree(c.w, c.h);
			var placements = new Array<{rect:Dynamic, placed:Dynamic}>();
			var ok = true;
			for (r in rects) {
				var placed = packer.insert(r.w, r.h);
				if (placed == null) {
					ok = false;
					break;
				}
				placements.push({ rect: r, placed: placed });
			}

			if (ok) {
				// Build the final atlas BitmapData and entries mapping
				var atlasBD = new BitmapData(c.w, c.h, true, 0x00000000);
				var entries = new ObjectMap<BitmapData, TextureOptimizerPackedAtlasEntry>();

				for (p in placements) {
					var r = p.rect;
					var pl = p.placed;
					var destX = pl.x + padding;
					var destY = pl.y + padding;

					// copyPixels requires a Rectangle and Point
					atlasBD.copyPixels(r.bitmap, new Rectangle(0, 0, r.origW, r.origH), new Point(destX, destY));

					var entry:TextureOptimizerPackedAtlasEntry = {
						bitmapData: r.bitmap,
						width: Std.int(r.origW),
						height: Std.int(r.origH),
						x: destX,
						y: destY
					};
					entries.set(r.bitmap, entry);
				}
				
				Debugger.log("bmpd ret", {
					bitmapData: atlasBD,
					width: c.w,
					height: c.h,
					entries: entries
				});

				return {
					bitmapData: atlasBD,
					width: c.w,
					height: c.h,
					entries: entries
				};
			}
		}

		// couldn't pack into any candidate atlas
		return null;
	}
}
