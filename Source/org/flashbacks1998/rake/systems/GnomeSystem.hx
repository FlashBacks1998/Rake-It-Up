package org.flashbacks1998.rake.systems;

import org.flashbacks1998.world3d.geom.Position3D;
import hscript.Expr;
import hscript.Parser;

import org.flashbacks1998.debugger.Debugger;
import org.flashbacks1998.newgrounds.Newgrounds;
import org.flashbacks1998.rake.ui.GnomeEditWindow;
import org.flashbacks1998.rake.ui.GnomeStatusWindow;

class GnomeSystem {

    public var parser = new Parser();
    public var expression:Expr = null;
    public var interp = new hscript.Interp();

    public static var defaultSource =
        "// ================== Welcome to the Gnome System! ==================\n" +
        "// This is a little embedded Hscript interpreter that you can use to\n" +
        "// control the gnome's position, rotation, etc. Every single leaf\n" +
        "// that the gnome touches will be raked and scored!\n\n" +

        "// The gnome's position is stored in the variable `position` \n" +
        "// The overall elapsed time (ms) is stored in `elapsed` \n\n" +

        "var radius = 7;\n" +
        "var degrees = (elapsed / 100) % 360;\n" +
        "var radians = degrees * Math.PI / 180;\n" +
        "position.x = radius * Math.cos(radians);\n" +
        "position.z = radius * Math.sin(radians);\n\n" +

        "var degreeYaw = (-degrees + 90) % 360;\n" +
        "position.yaw = degreeYaw;\n";

    /** The window currently bound to this system, set by `attachWindow`. */
    public var window:GnomeEditWindow;

    /**
     * Status surface used as a workaround for the broken NotificationManager.
     * Optional — if null, results only go to Debugger.log.
     */
    public var statusWindow:GnomeStatusWindow;

    /** The active hscript source — the source of truth that the window mirrors. */
    public var source = defaultSource;

    /**
     * Tracks the last runtime-error message emitted by `run()` so the per-frame
     * update loop doesn't re-trigger `statusWindow.showError` on every tick when
     * the user's script has a persistent runtime error.
     */
    private var _lastRunError:String = null;

    /**
     * Local de-dupe for the "Gnome modification" Newgrounds medal — flips true
     * the first frame a non-default source executes cleanly. Prevents us from
     * re-checking the medal map every tick once the medal has been awarded.
     */
    private var _medalGnomeModAwarded:Bool = false;

    public function new() {
        interp.variables.set("trace", (x)->{Debugger.log("GNOME", x);});
        interp.variables.set("Math", Math);
    }

    public function attachWindow(w:GnomeEditWindow):Void {
        window = w;
        if (window == null) return;

        window.bodyText = source;

        window.resetButton.onClick  = _ -> onResetButton();
        window.updateButton.onClick = _ -> onUpdateButton();

        // Initial parse pass so the script is ready for the first update tick.
        // No status notification — this is automatic, not user-initiated.
        upload(false);
    }

    /**
     * Bind a status surface that this system reports outcomes through. Replaces
     * the haxe.ui NotificationManager hookup, which is currently broken.
     */
    public function attachStatusWindow(w:GnomeStatusWindow):Void {
        statusWindow = w;
    }

    public function onResetButton():Void {
        Debugger.log("GnomeSystem.onResetButton: reverting to defaultSource");
        source = defaultSource;
        if (window != null) window.bodyText = source;
        upload();
        run();
    }

    public function onUpdateButton():Void {
        Debugger.log("GnomeSystem.onUpdateButton: pulling text from window and uploading");
        if (window != null) source = window.bodyText;
        upload();
        run();
    }

    public function setPosition(position:Position3D) {
        interp.variables.set("position", position);
    }

    public function setElapsed(elapsed:Float):Void {
        interp.variables.set("elapsed", elapsed);
    }

    public function update(elapsed:Float):Void {
        setElapsed(elapsed);
        run();
    }

    /**
     * Persist + parse. `showStatus` controls whether the bound status window is
     * notified — passed false during the silent attach-time priming so the
     * window doesn't pop up before the user has done anything.
     */
    public function upload(showStatus:Bool = true):Void {
        Debugger.log("GnomeSystem.upload:", (source != null ? source.length : 0), "chars");
        Newgrounds.saveCloudGnomeSource(source);

        try {
            expression = parser.parseString(source);

            // Successful re-parse: any prior runtime-error de-dupe is stale.
            _lastRunError = null;

            if (showStatus && statusWindow != null) {
                statusWindow.showSuccess("Successfully updated the Gnome script");
            }
        } catch (e:Dynamic) {
            Debugger.log("GnomeSystem.upload: parse threw", e);
            expression = null;

            if (showStatus && statusWindow != null) {
                statusWindow.showError("Parse error", Std.string(e));
            }
        }
    }

    /**
     * Execute the most recently parsed expression. Called per-frame by `update`,
     * so runtime errors are de-duped via `_lastRunError` to avoid spamming the
     * status window on a script that fails every tick.
     */
    public function run():Void {
        Debugger.log("GnomeSystem.run executing");
        if (expression == null) return;

        try {
            interp.execute(expression);

            // Recovery from a previous runtime error: clear the de-dupe slot
            // (we don't pop a green status here; success-on-every-frame would
            // be noise — the status was already announced at upload time).
            _lastRunError = null;

            // Award the "Gnome modification" medal the first frame a non-default
            // script runs cleanly. Local flag prevents re-checking the NG medal
            // map every tick once we've already unlocked it.
            if (!_medalGnomeModAwarded && source != null && source != defaultSource) {
                _medalGnomeModAwarded = true;
                Newgrounds.unlockMedal(Newgrounds.MEDAL_GNOME_MODIFICATION);
            }
        } catch (e:Dynamic) {
            final msg = Std.string(e);
            Debugger.log("GnomeSystem.run: exec threw", e);

            if (statusWindow != null && msg != _lastRunError) {
                statusWindow.showError("Runtime error", msg);
                _lastRunError = msg;
            }
        }
    }
}
