package org.flashbacks1998.debugger;

import openfl.events.Event;

/**
 * Dispatched by Debugger whenever a new log entry is created.
 */
class DebuggerEventNewLogs extends Event {
    public static final NEW_LOGS:String = "DebuggerEvent.NEW_LOGS";

    public var logs:Array<DebuggerLog>;

    public function new(
        type:String,
        logs:Array<DebuggerLog>,
        bubbles:Bool = false,
        cancelable:Bool = false
    ) {
        super(type, bubbles, cancelable);
        this.logs = logs;
    }

    override public function clone():Event {
        var logsCopy = (logs == null) ? null : logs.copy();
        return new DebuggerEventNewLogs(type, logsCopy, bubbles, cancelable);
    }

    override public function toString():String {
        return '[DebuggerEventNewLog type=' + type +
               ' logs=' + (logs == null ? "null" : cast logs.length) +
               ' bubbles=' + bubbles +
               ' cancelable=' + cancelable + ']';
    }
}
