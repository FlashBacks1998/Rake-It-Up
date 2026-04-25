package org.flashbacks1998.debugger;

import org.flashbacks1998.debugger.DebuggerLog;
import org.flashbacks1998.debugger.DebuggerLog.DebuggerType;
import org.flashbacks1998.debugger.DebuggerEventNewLogs;
import openfl.Lib;
import haxe.CallStack.StackItem;
import openfl.events.Event;
import openfl.events.EventDispatcher;

#if !html5
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;
#end

class Debugger extends EventDispatcher {
    /** runtime log storage (available at runtime) */
    public static var logs:Array<DebuggerLog> = []; 
    public static var _logsToDispatch:Array<DebuggerLog> = []; // used internally for batching new logs in onEnterFrame

    public static var worldTTR:Float = 0;
    public static var physicsTTR:Float = 0;
    // Physics sub‑phase timings — populated by Physics3D.step() when the caller
    // wraps `physics.step(dt)` in a `physicsTTR` measurement. Visible in the
    // DebuggerStats overlay as `int/col/res/bnd/snd`.
    public static var leavesTTR:Float = 0;             // leafsSystem.update + updateColor wall time
    public static var physicsIntegrateTTR:Float = 0;   // velocity -> position integration
    public static var physicsCollisionTTR:Float = 0;   // testForCollisions (broad+narrow phase)
    public static var physicsResolveTTR:Float = 0;     // positional correction + sensor record
    public static var physicsBoundsTTR:Float = 0;      // world-bounds enforcement
    public static var physicsSensorDispatchTTR:Float = 0; // Physics3D.resolveSensorCollisions
    // Physics scene-state counts (also rendered by DebuggerStats).
    public static var physicsPairCount:UInt = 0;       // _objectsToTest.length after last step
    public static var physicsCollisionCount:UInt = 0;  // _totalCollisions after last step
    public static var physicsSensorCollisionCount:UInt = 0; // _sensorCollisions.length after last step
    public static var trianglesRendered:UInt = 0;
    public static var meshesRendered:UInt = 0;
    public static var meshesCulled:UInt = 0;

    // Pool batching counters (software renderer)
    public static var softwarePoolsBeforeBatch:UInt = 0;
    public static var softwarePoolsAfterBatch:UInt = 0;
    public static var softwareBatchBuckets:UInt = 0;
    public static var softwareBatchCandidatePools:UInt = 0;
    public static var softwareFlushCalls:UInt = 0;
    public static var softwareBatchBuildTTR:Float = 0;

    private static var _instance:Debugger;
    public static var instance(get, null):Debugger;
    public static function get_instance():Debugger {
        if (instance == null) instance = new Debugger();
        return instance;
    }

    /** Max characters allowed for the concatenated args string */
    public static inline var MAX_CONCAT_CHARS:Int = 1000;

    public function new() {
        super(); 
    }

    private static var _logIndex = 0;
 
    /**
     * Centralized API for adding a new log record.
     * Accepts a DebuggerLog (construct it before calling).
     */
    public function newLog(log:DebuggerLog):Void {
        logs.push(log);
        _logsToDispatch.push(log);

        if(Lib.current != null && Lib.current.stage != null)
        Lib.current.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame);
    }

    public function onEnterFrame(e:Event) {
        Lib.current.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        dispatchEvent(new DebuggerEventNewLogs(DebuggerEventNewLogs.NEW_LOGS, _logsToDispatch));
        _logsToDispatch = [];
    }

    // ────────────────────────────── COMMON HELPERS ──────────────────────────────

    /** Truncate a string to <= max characters (adds "…" if truncated). */
    public static inline function limitStr(s:String, max:Int = MAX_CONCAT_CHARS):String {
        if (s == null) return "";
        if (max <= 0) return "";
        if (s.length <= max) return s;

        var suffix = "…";
        if (max <= suffix.length) return suffix.substr(0, max);
        return s.substr(0, max - suffix.length) + suffix;
    }

    /** helper to get all logs as a single string */
    public static function getLogsStr():String {
        return logs.join("\n");
    }

    public static function getTime():Int {
        return openfl.Lib.getTimer();
    }

    public static function reset():Void {
        meshesRendered = 0;
        trianglesRendered = 0;
        meshesCulled = 0;
        softwarePoolsBeforeBatch = 0;
        softwarePoolsAfterBatch = 0;
        softwareBatchBuckets = 0;
        softwareBatchCandidatePools = 0;
        softwareFlushCalls = 0;
        softwareBatchBuildTTR = 0;
        // Zero per-frame physics sub-timings so values reflect this frame only.
        leavesTTR = 0;
        physicsIntegrateTTR = 0;
        physicsCollisionTTR = 0;
        physicsResolveTTR = 0;
        physicsBoundsTTR = 0;
        physicsSensorDispatchTTR = 0;
        physicsPairCount = 0;
        physicsCollisionCount = 0;
        physicsSensorCollisionCount = 0;
    }

    #if !html5
    // ───────────────────────────────── MACRO SIDE ─────────────────────────────────

    public static macro function error(args:Array<Expr>):Expr {
        // capture location
        var loc = PositionTools.toLocation(Context.currentPos());
        var file = loc.file;
        var line = loc.range.start.line;

        // package + class (compile-time)
        var c = Context.getLocalClass();
        var packagenm = "";
        var classnm = "";
        if (c != null) {
            var ci = c.get();
            classnm = ci.name;
            packagenm = ci.pack.join(".");
        }

        // function/method name (best effort)
        var funcnm = Std.string(Context.getLocalMethod());

        // build base message expression: prepend "[ERROR]" then all args stringified
        var sExprs:Array<Expr> = [macro "[ERROR]"];
        for (a in args) sExprs.push(macro Std.string($e{a}));
        if (sExprs.length == 0) sExprs.push(macro "[ERROR]");

        var base:Expr = sExprs[0];
        for (i in 1...sExprs.length) {
            base = macro $e{base} + " " + $e{sExprs[i]};
        }

        // CAP the args portion to avoid huge object-to-string expansions
        base = macro org.flashbacks1998.debugger.Debugger.limitStr($e{base}, org.flashbacks1998.debugger.Debugger.MAX_CONCAT_CHARS);

        // append current stack trace at runtime (kept intact)
        var stackExpr:Expr = macro haxe.CallStack.toString(haxe.CallStack.callStack());
        var concat:Expr = macro $e{base} + "\n" + $e{stackExpr};

        return macro {
            var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
            var _args:Array<Dynamic> = [$a{args}];
            var _msg:String = Std.string(_t) + "\t" + $v{file} + ":" + Std.string($v{line}) + " - " + $e{concat};

            trace(_msg);

            // create a DebuggerLog record and push via the newLog API
            var rec = new org.flashbacks1998.debugger.DebuggerLog($v{packagenm}, $v{classnm}, $v{funcnm}, $v{line}, _args, _msg, org.flashbacks1998.debugger.DebuggerLog.DebuggerType.Error);
            org.flashbacks1998.debugger.Debugger.instance.newLog(rec);
        };
    }

    /**
     * Macro entry-point: captures file+line, stringifies args,
     * and emits code that pushes into logs via newLog (so batching happens in onEnterFrame)
     */
    public static macro function log(args:Array<Expr>):Expr {
        // capture location
        var loc = PositionTools.toLocation(Context.currentPos());
        var file = loc.file;
        var line = loc.range.start.line;

        // package + class (compile-time)
        var c = Context.getLocalClass();
        var packagenm = "";
        var classnm = "";
        if (c != null) {
            var ci = c.get();
            classnm = ci.name;
            packagenm = ci.pack.join(".");
        }

        // function/method name (best effort)
        var funcnm = Std.string(Context.getLocalMethod());

        // stringify args for message, keep raw args for the event
        var sExprs:Array<Expr> = [];
        for (a in args) sExprs.push(macro Std.string($e{a}));
        if (sExprs.length == 0) sExprs.push(macro "");

        var concat:Expr = sExprs[0];
        for (i in 1...sExprs.length) {
            concat = macro $e{concat} + " " + $e{sExprs[i]};
        }

        // CAP the concatenated string
        concat = macro org.flashbacks1998.debugger.Debugger.limitStr($e{concat}, org.flashbacks1998.debugger.Debugger.MAX_CONCAT_CHARS);

        return macro {
            var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
            var _args:Array<Dynamic> = [$a{args}];
            var _msg:String = Std.string(_t) + "\t" + $v{file} + ":" + Std.string($v{line}) + " - " + $e{concat};

            trace(_msg);

            // create DebuggerLog and push via newLog
            var rec = new org.flashbacks1998.debugger.DebuggerLog($v{packagenm}, $v{classnm}, $v{funcnm}, $v{line}, _args, _msg, org.flashbacks1998.debugger.DebuggerLog.DebuggerType.Log);
            org.flashbacks1998.debugger.Debugger.instance.newLog(rec);
        };
    }

    #else
    // ─────────────────────────────── RUNTIME (HTML5) ───────────────────────────────
    // No macros. Keeps the same call style: Debugger.log("a", x, y)

    private static inline var SELF_CLASS:String = "org.flashbacks1998.debugger.Debugger";

    private static function _callerInfo():{file:String, line:Int, packagenm:String, classnm:String, funcnm:String} {
        var file = "unknown";
        var line = 0;
        var classPath = "";
        var func = "";

        var stack = haxe.CallStack.callStack();
        var found = false;

        for (it in stack) {
            switch (it) {
                case StackItem.FilePos(sub, f, l):
                    switch (sub) {
                        case StackItem.Method(c, m):
                            // skip frames inside Debugger itself
                            if (c != SELF_CLASS) {
                                file = f;
                                line = l;
                                classPath = c;
                                func = m;
                                found = true;
                            }
                        default:
                    }
                default:
            }
            if (found) break;
        }

        var packagenm = "";
        var classnm = classPath;
        if (classPath != null && classPath.length > 0) {
            var parts = classPath.split(".");
            classnm = parts.pop();
            packagenm = parts.join(".");
        }

        return { file: file, line: line, packagenm: packagenm, classnm: classnm, funcnm: func };
    }

    public static function log(args:haxe.extern.Rest<Dynamic>):Void {
        var info = _callerInfo();

        var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
        var _args:Array<Dynamic> = [for (a in args) a];

        var parts:Array<String> = [];
        for (a in _args) parts.push(Std.string(a));
        var concat = (parts.length == 0) ? "" : parts.join(" ");

        // CAP concat
        concat = org.flashbacks1998.debugger.Debugger.limitStr(concat, org.flashbacks1998.debugger.Debugger.MAX_CONCAT_CHARS);

        var _msg:String = Std.string(_t) + "\t" + info.file + ":" + Std.string(info.line) + " - " + concat;

        trace(_msg);

        // create DebuggerLog and add it via newLog (so onEnterFrame will batch-dispatch)
        var rec = new org.flashbacks1998.debugger.DebuggerLog(info.packagenm, info.classnm, info.funcnm, info.line, _args, _msg, org.flashbacks1998.debugger.DebuggerLog.DebuggerType.Log);
        org.flashbacks1998.debugger.Debugger.instance.newLog(rec);
    }

    public static function error(args:haxe.extern.Rest<Dynamic>):Void {
        var info = _callerInfo();

        var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
        var _args:Array<Dynamic> = [for (a in args) a];

        var parts:Array<String> = ["[ERROR]"];
        for (a in _args) parts.push(Std.string(a));
        var base = parts.join(" ");

        // CAP args portion; keep stack appended after
        base = org.flashbacks1998.debugger.Debugger.limitStr(base, org.flashbacks1998.debugger.Debugger.MAX_CONCAT_CHARS);

        var stackStr = haxe.CallStack.toString(haxe.CallStack.callStack());
        var concat = base + "\n" + stackStr;

        var _msg:String = Std.string(_t) + "\t" + info.file + ":" + Std.string(info.line) + " - " + concat;

        trace(_msg);

        // create DebuggerLog and add it via newLog
        var rec = new org.flashbacks1998.debugger.DebuggerLog(info.packagenm, info.classnm, info.funcnm, info.line, _args, _msg, org.flashbacks1998.debugger.DebuggerLog.DebuggerType.Error);
        org.flashbacks1998.debugger.Debugger.instance.newLog(rec);
    }
    #end
}
