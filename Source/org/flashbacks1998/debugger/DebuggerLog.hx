package org.flashbacks1998.debugger;

import haxe.Json;

/**
 * DebuggerType - types of debug records.
 */
enum abstract DebuggerType(String) {
    var Log;
    var Error;
    var Warn;
}

/**
 * DebuggerLog - lightweight struct-like class for debugger/log entries.
 */
@:structInit
class DebuggerLog {
    public var packagenm:String;
    public var classnm:String;
    public var funcnm:String;
    public var lineno:Int;
    public var args:Array<Dynamic>;
    public var msg:String;
    public var type:DebuggerType;

    /**
     * Supports BOTH:
     *   new DebuggerLog({...})     // struct init
     *   new DebuggerLog(a,b,c,d,e,f,g) // positional
     */
    public function new(
        ?packagenm:String,
        ?classnm:String,
        ?funcnm:String,
        ?lineno:Int,
        ?args:Array<Dynamic>,
        ?msg:String,
        ?type:DebuggerType
    ) {
        this.packagenm = packagenm;
        this.classnm   = classnm;
        this.funcnm    = funcnm;
        this.lineno    = lineno;
        this.args      = args;
        this.msg       = msg;
        this.type      = type;
    }

    /**
     * Short string form for logging.
     */
    public function toString():String {
        var t = (type == null) ? "NLog" : cast(type, String);
        var a = (args == null) ? "[]" : Std.string(args);

        return "[" + t + "] " +
               (packagenm != null ? packagenm + "." : "") +
               (classnm   != null ? classnm   + "." : "") +
               (funcnm    != null ? funcnm : "") +
               (lineno > 0 ? " (line " + lineno + ")" : "") +
               " -- " + (msg != null ? msg : "") +
               " args=" + a;
    }

    /**
     * JSON helper
     */
    public function toJson():String {
        return Json.stringify({
            packagenm: packagenm,
            classnm: classnm,
            funcnm: funcnm,
            lineno: lineno,
            args: args,
            msg: msg,
            type: (type == null ? null : cast type)
        });
    }
}
