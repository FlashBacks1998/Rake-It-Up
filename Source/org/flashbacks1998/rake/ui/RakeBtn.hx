package org.flashbacks1998.rake.ui;

import haxe.ui.components.Button;
import haxe.ui.events.MouseEvent;

/**
    Rake tool state — the button cycles between `Rake` (garden raking)
    and `Move` (camera/directional movement). Used by SceneMain /
    SceneTestSR01 to decide which input handler runs.
**/
enum RakeButtonStage { Rake; Move; }

@:xml('
<button styleName="game-button" icon="assets/textures/rake.gif" />
')
class RakeBtn extends Button {
    public var state(default, set):RakeButtonStage = Rake;

    /** Optional hook for callers that want to react to state changes beyond
        the scene's CLICK handler (e.g. if downstream code cares about the
        *new* state, not just the act of clicking). **/
    public var onStateChange:RakeButtonStage->Void = null;

    public function new() {
        super();
        registerEvent(MouseEvent.CLICK, onRakeClick);
    }

    private function onRakeClick(_:MouseEvent):Void {
        state = (state == Move) ? Rake : Move;
    }

    private function set_state(s:RakeButtonStage):RakeButtonStage {
        this.state = s;
        icon = (s == Rake)
            ? "assets/textures/rake.gif"
            : "assets/textures/icons8-directions-64.png";
        if (onStateChange != null) onStateChange(s);
        return s;
    }
}
