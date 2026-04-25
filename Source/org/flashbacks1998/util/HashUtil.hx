package org.flashbacks1998.util;

class HashUtil {
    /**
     * FNV-1a 32-bit
     * Returns signed 32-bit int (Haxe Int).
     */
    public static function fnv1a32(s:String):Int {
        var hash:Int = 0x811c9dc5; // FNV offset basis
        var i = 0;
        var len = s.length;
        while (i < len) {
            var c = s.charCodeAt(i++);
            // process low 8 bits
            hash = (hash ^ (c & 0xFF)) * 0x01000193;
            // process high 8 bits if present (UTF-16 code unit may be >255)
            var hi = (c >> 8) & 0xFF;
            if (hi != 0) {
                hash = (hash ^ hi) * 0x01000193;
            }
            // keep as 32-bit
            hash = hash | 0;
        }
        return hash;
    }
}
