package org.flashbacks1998.debugger;

import openfl.events.Event;
import openfl.events.EventDispatcher;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.PositionTools;
#end

class Debugger {
    /** runtime log storage (available at runtime) */
    public static var logs:Array<String> = [];

    public static var trianglesRendered:UInt = 0;
    public static var meshesRendered:UInt = 0;

    public static var _instance:Debugger;
    public static var dispatcher:EventDispatcher = new EventDispatcher();

    public function new() {
        
    }

    public static function getInstance():Debugger {
        if (_instance == null)
            _instance = new Debugger();
        return _instance;
    }

    // ───────────────────────────────── MACRO SIDE ─────────────────────────────────
    #if macro
 
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

        // build message expression: prepend "[ERROR]" then all args stringified
        var sExprs:Array<Expr> = [macro "[ERROR]"];
        for (a in args) sExprs.push(macro Std.string($e{a}));
        if (sExprs.length == 0) sExprs.push(macro "[ERROR]");

        var concat:Expr = sExprs[0];
        for (i in 1...sExprs.length) {
            concat = macro $e{concat} + " " + $e{sExprs[i]};
        }

        // append current stack trace at runtime
        var stackExpr:Expr = macro haxe.CallStack.toString(haxe.CallStack.callStack());
        concat = macro $e{concat} + "\n" + $e{stackExpr};

        return macro {
            var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
            var _args:Array<Dynamic> = [$a{args}];
            var _msg:String = Std.string(_t) + "\t" + $v{file} + ":" + Std.string($v{line}) + " - " + $e{concat};

            trace(_msg);

            org.flashbacks1998.debugger.Debugger.logs.push(_msg);

            org.flashbacks1998.debugger.Debugger.dispatcher.dispatchEvent(
                new org.flashbacks1998.debugger.DebuggerEventNewLog(
                    org.flashbacks1998.debugger.DebuggerEventNewLog.NEW_LOG,
                    $v{packagenm},
                    $v{classnm},
                    $v{funcnm},
                    $v{line},
                    _args,
                    _msg
                )
            );
        };
    } 


    /**
     * Macro entry-point: captures file+line, stringifies args,
     * and emits code that pushes into logs, dispatches an event, and traces.
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

        return macro {
            var _t:Int = org.flashbacks1998.debugger.Debugger.getTime();
            var _args:Array<Dynamic> = [$a{args}];
            var _msg:String = Std.string(_t) + "\t" + $v{file} + ":" + Std.string($v{line}) + " - " + $e{concat};

            trace(_msg);

            org.flashbacks1998.debugger.Debugger.logs.push(_msg);

            org.flashbacks1998.debugger.Debugger.dispatcher.dispatchEvent(
                new org.flashbacks1998.debugger.DebuggerEventNewLog(
                    org.flashbacks1998.debugger.DebuggerEventNewLog.NEW_LOG,
                    $v{packagenm},
                    $v{classnm},
                    $v{funcnm},
                    $v{line},
                    _args,
                    _msg
                )
            );
        };
    }

    // ─────────────────────────────── RUNTIME SIDE ───────────────────────────────
    #else

    /**
     * Runtime `error` (non-macro): builds a message, stores it, dispatches too.
     * Call normally: `Debugger.error("something went wrong", code);`
     */ 
    public static inline function error(rest:haxe.Rest<Dynamic>):Void {
        var args:Array<Dynamic> = rest; // Rest<T> is backed by Array<T>

        var stack = haxe.CallStack.toString(haxe.CallStack.callStack());

        // prepend an "[ERROR]" tag for the message/event and append stack at the end
        var tagged:Array<Dynamic> = ["[ERROR]"];
        tagged = tagged.concat(args);
        tagged.push(stack);

        runtimeLogImpl(tagged, "runtime", "Debugger", "error", 0);
    }


    /**
     * Runtime `log` (non-macro): same behavior shape as macro version
     * but without compile-time file/class info.
     *
     * Call normally: `Debugger.log("hello", someValue);`
     */
    public static inline function log(rest:haxe.Rest<Dynamic>):Void {
        var args:Array<Dynamic> = rest;
        runtimeLogImpl(args, "runtime", "Debugger", "log", 0);
    }

    /**
     * Shared runtime implementation: builds msg, pushes into logs, dispatches.
     */
    static inline function runtimeLogImpl(
        args:Array<Dynamic>,
        packagenm:String,
        classnm:String,
        funcnm:String,
        lineno:Int
    ):Void {
        var t:Int = getTime();

        var parts:Array<String> = [];
        for (v in args) { 
            if(Std.isOfType(v, String)) {
                parts.push(v);
            }
            else { 
                final s = Std.string(v);
                parts.push(
                    s.length < 256 ? s : s.substr(0, 256) + "..."
                );
            }
        }
        var msgBody = parts.length > 0 ? parts.join(" ") : "";
        var msg = Std.string(t) + "\t" + packagenm + ":" + Std.string(lineno) + " - " + msgBody;

        trace(msg);
        logs.push(msg);

        dispatcher.dispatchEvent(
            new DebuggerEventNewLog(
                DebuggerEventNewLog.NEW_LOG,
                packagenm,
                classnm,
                funcnm,
                lineno,
                args,
                msg
            )
        );
    }

    #end // #if macro / #else

    // ────────────────────────────── COMMON HELPERS ──────────────────────────────

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
    }
}
