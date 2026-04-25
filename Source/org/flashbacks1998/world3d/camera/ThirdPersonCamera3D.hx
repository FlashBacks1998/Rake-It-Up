package org.flashbacks1998.world3d.camera;

import org.flashbacks1998.world3d.geom.Position3D;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;
import openfl.utils.PerspectiveMatrix3D;
import org.flashbacks1998.world3d.util.Constants;

/**
 * Third-person camera that orbits a target point at configurable radii.
 */
class ThirdPersonCamera3D extends Camera3D {
    public var center:Position3D;           // The focus point

    public var radiusX(get, set):Float;
    public var radiusY(get, set):Float;
    public var radiusZ(get, set):Float;

    private var _radiusX:Float;
    private var _radiusY:Float;
    private var _radiusZ:Float;

    // Used to avoid doing math while base ctor is still running
    private var _initialized:Bool = false;
 
    private var _horizontalDeg:Float = 0; // orbit angle around Y in degrees
    private var _verticalDeg:Float   = 15; // elevation angle in degrees

    public function new(centerPoint:Position3D, radiusX:Float = 3, radiusY:Float = 1.75, radiusZ:Float = 3) {
        super(); // Camera3D ctor may call updateView() -> we guard against it

        center   = (centerPoint != null) ? centerPoint : new Position3D();
        _radiusX = radiusX;
        _radiusY = radiusY;
        _radiusZ = radiusZ;

        _initialized = true;
        _dirtyView = true;
        updateView(); // now safe: center is non-null and _initialized is true
    }

    /**
     * Rotate around the center horizontally by delta degrees.
     */
    public function shiftVertical(deltaDeg:Float):Void {
        _horizontalDeg += deltaDeg;
        _horizontalDeg %= 360;
        _dirtyView = true;
    }

    /**
     * Move camera elevation up/down by delta degrees (clamped).
     */
    public function shiftHorizontal(deltaDeg:Float):Void {
        _verticalDeg = Math.min(89, Math.max(-89, _verticalDeg + deltaDeg));
        _dirtyView = true;
    }

    /**
     * Explicitly set horizontal/vertical angles (used for Q/E iso rotation).
     */
    public function setAngles(horizontalDeg:Float, verticalDeg:Float):Void {
        _horizontalDeg = horizontalDeg;
        _verticalDeg   = verticalDeg;
        _dirtyView = true;
        if (_initialized) updateView();
    }

    /**
     * Recompute view matrix based on spherical coordinates around center.
     */
    override public function updateView():Void {
        // Early-out while base Camera3D ctor is still running
        if (!_initialized || center == null) return;

        var hRad = _horizontalDeg * Constants.DEGREES_TO_RADIANS;
        var vRad = _verticalDeg   * Constants.DEGREES_TO_RADIANS;

        // Spherical position around center
        _x = center.x + Math.cos(vRad) * Math.sin(hRad) * _radiusX;
        _y = center.y + Math.sin(vRad) * _radiusY;
        _z = center.z + Math.cos(vRad) * Math.cos(hRad) * _radiusZ;

        // Look at the center point
        super.lookAt(center.x, center.y, center.z);
        super.updateView();
    }

    // --- radius properties ---

    public function get_radiusX():Float return _radiusX;
    public function set_radiusX(v:Float):Float {
        _radiusX = v;
        _dirtyView = true;
        if (_initialized) updateView();
        return v;
    }

    public function get_radiusY():Float return _radiusY;
    public function set_radiusY(v:Float):Float {
        _radiusY = v;
        _dirtyView = true;
        if (_initialized) updateView();
        return v;
    }

    public function get_radiusZ():Float return _radiusZ;
    public function set_radiusZ(v:Float):Float {
        _radiusZ = v;
        _dirtyView = true;
        if (_initialized) updateView();
        return v;
    }

    /**
     * Update the center position (if not sharing an external Position3D).
     * In your Knight game you’re doing `_camera.center = _knightBody.position`
     * so you may not need this, but it’s still useful elsewhere.
     */
    public function updateCenter(x:Float, y:Float, z:Float):Void {
        center.setTo(x, y, z);
        _dirtyView = true;
    }
}
