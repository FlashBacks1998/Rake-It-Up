package org.flashbacks1998.debugger;

//import org.flashbacks1998.ruffle.Ruffle;
import openfl.system.Capabilities;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.Lib;
import org.flashbacks1998.newgrounds.Newgrounds;

class DebuggerStats extends Sprite { 
    var tf:TextField;

    // FPS tracking
    var fps:Float = 0;
    var frames:Int = 0;
    var fpsWindowStart:Int = 0;

    public function new() {
        super();

        // simple text field for the overlay
        tf = new TextField();
        tf.width = 340;   // widened for physics sub-timing columns
        tf.height = 295;  // +50px for the new Leaves / Phys sub-timing / Phys counts lines
        tf.selectable = true;
        tf.mouseEnabled = true;

        var fmt = new TextFormat("_sans", 12, 0xFFFFFF);
        tf.defaultTextFormat = fmt;
        tf.text = "DebuggerStats starting...";
        addChild(tf);

        graphics.beginFill(0x000000, 0.55);
        graphics.drawRect(0, 0, tf.width, tf.height);
        graphics.endFill();

        addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
    }

    public function onAddedToStage(e:Event):Void {
        removeEventListener(Event.ADDED_TO_STAGE, onAddedToStage);

        fpsWindowStart = Lib.getTimer();
        frames = 0;

        addEventListener(Event.ENTER_FRAME, onEnterFrame);
        addEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }

    public function onEnterFrame(e:Event):Void {
        // FPS calculation (rolling once per ~1000 ms)
        frames++;
        var now = Lib.getTimer();
        var elapsed = now - fpsWindowStart;
        if (elapsed >= 1000) {
            fps = frames * 1000.0 / elapsed;
            frames = 0;
            fpsWindowStart = now;
        }

        // Read current counters exposed by Debugger
        var meshes = Debugger.meshesRendered;
        var tris = Debugger.trianglesRendered;

        // Display (trim FPS to one decimal)
        var fpsStr = (Math.floor(fps * 10) / 10) + "";
        // Newgrounds status: API connectivity + login state + save payload.
        var ngApi    = Newgrounds.isConnected() ? "connected" : "offline";
        var ngLogin  = Newgrounds.getStatusLine();
        var ngSave   = Newgrounds.getLoadedCloudSaveJson();

        // Physics sub-timings — trim to 1 decimal ms for readability.
        inline function fmt1(v:Float):String return (Math.floor(v * 10) / 10) + "";
        tf.text =
            "FPS: " + fpsStr + "\n" +
            "World TTR: " + Debugger.worldTTR + "\n" +
            "Leaves TTR: " + Debugger.leavesTTR + "\n" +
            "Physics TTR: " + Debugger.physicsTTR +
                " (int:" + fmt1(Debugger.physicsIntegrateTTR) +
                " col:"  + fmt1(Debugger.physicsCollisionTTR) +
                " res:"  + fmt1(Debugger.physicsResolveTTR) +
                " bnd:"  + fmt1(Debugger.physicsBoundsTTR) +
                " snd:"  + fmt1(Debugger.physicsSensorDispatchTTR) + ")\n" +
            "Phys Counts: pairs=" + Debugger.physicsPairCount +
                " cols=" + Debugger.physicsCollisionCount +
                " snd="  + Debugger.physicsSensorCollisionCount + "\n" +
            "Meshes: " + meshes + "\n" +
            "Triangles: " + tris + "\n" +
            "Pools: " + Debugger.softwarePoolsBeforeBatch + "+" +
                Debugger.softwareBatchCandidatePools + " -> " +
                Debugger.softwarePoolsAfterBatch + "\n" +
            "Buckets: " + Debugger.softwareBatchBuckets +
                "  Flushes: " + Debugger.softwareFlushCalls + "\n" +
            "BatchBuild: " + Debugger.softwareBatchBuildTTR + "ms\n" +
            "NG API: " + ngApi + "\n" +
            "NG Login: " + ngLogin + "\n" +
            "NG Save: " + (ngSave != null ? ngSave : "(none)") + "\n";

        Debugger.reset();
    }

    public function onRemovedFromStage(e:Event):Void {
        removeEventListener(Event.ENTER_FRAME, onEnterFrame);
        removeEventListener(Event.REMOVED_FROM_STAGE, onRemovedFromStage);
    }
}
