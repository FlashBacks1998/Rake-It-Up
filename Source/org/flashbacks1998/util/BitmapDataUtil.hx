package org.flashbacks1998.util;

import openfl.display.BitmapData;

class BitmapDataUtil {
    /**
 * Convert premultiplied BitmapData -> straight-alpha BitmapData.
 * Note: this reads/writes per pixel, so it's CPU-heavy for large images.
 */
public static function unpremultiplyBitmapData(src:BitmapData):BitmapData {
    if (src == null) return null;
    var w = src.width;
    var h = src.height;
    var out = new BitmapData(w, h, true, 0x00000000);

    for (y in 0...h) {
        for (x in 0...w) {
            var px:Int = src.getPixel32(x, y); // 0xAARRGGBB
            var a:Int = (px >> 24) & 0xFF;
            var r:Int = (px >> 16) & 0xFF;
            var g:Int = (px >> 8) & 0xFF;
            var b:Int = px & 0xFF;

            if (a == 0) {
                out.setPixel32(x, y, 0); // fully transparent
            } else {
                // r,g,b are premultiplied: r_prem = r_straight * a/255
                // so r_straight = r_prem * 255 / a
                var rf = Std.int(Math.min(255, Std.int(Math.round((r * 255.0) / a))));
                var gf = Std.int(Math.min(255, Std.int(Math.round((g * 255.0) / a))));
                var bf = Std.int(Math.min(255, Std.int(Math.round((b * 255.0) / a))));
                var outPx:Int = (a << 24) | (rf << 16) | (gf << 8) | bf;
                out.setPixel32(x, y, outPx);
            }
        }
    }

    return out;
}

}