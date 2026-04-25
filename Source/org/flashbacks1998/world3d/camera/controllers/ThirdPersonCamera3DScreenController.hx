package org.flashbacks1998.world3d.camera.controllers;

import openfl.Lib;
import openfl.events.MouseEvent;

class ThirdPersonCamera3DScreenController {
    private var camera:ThirdPersonCamera3D;
    private var dragging:Bool = false;
    private var lastX:Float = 0;
    private var lastY:Float = 0;
    private var sensitivityX:Float;
    private var sensitivityY:Float;

    private var _enabled:Bool = false;
    public var enabled(get, set):Bool;

    public function new(camera:ThirdPersonCamera3D, sensX:Float = 0.5, sensY:Float = 0.5) {
        this.camera = camera;
        this.sensitivityX = sensX;
        this.sensitivityY = sensY;
        enabled = true;
    }

    private function get_enabled():Bool return _enabled;

    private function set_enabled(v:Bool):Bool {
        if (_enabled == v) return _enabled;
        _enabled = v;

        // Always stop drag when toggling
        dragging = false;

        var st = Lib.current.stage;
        if (st == null) return _enabled;

        if (v) {
            st.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
            st.addEventListener(MouseEvent.MOUSE_UP, onMouseUp);
            st.addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        } else {
            st.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDown);
            st.removeEventListener(MouseEvent.MOUSE_UP, onMouseUp);
            st.removeEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);
        }

        return _enabled;
    }

    private function onMouseDown(e:MouseEvent):Void {
        dragging = true;
        lastX = e.stageX;
        lastY = e.stageY;
    }

    private function onMouseUp(e:MouseEvent):Void {
        dragging = false;
    }

    private function onMouseMove(e:MouseEvent):Void {
        if (!_enabled || !dragging) return;

        var dx = e.stageX - lastX;
        var dy = e.stageY - lastY;
        lastX = e.stageX;
        lastY = e.stageY;

        camera.shiftVertical(dx * sensitivityX);
        camera.shiftHorizontal(dy * sensitivityY);
        camera.updateMatrices();
    }

    public function update(delta:Float):Void {}
}