package org.flashbacks1998.world3d.camera;

import org.flashbacks1998.debugger.Debugger;
import openfl.geom.Matrix3D;
import openfl.geom.Vector3D;
import openfl.utils.PerspectiveMatrix3D;
import org.flashbacks1998.world3d.util.Constants;

class Camera3D {
    public var view:Matrix3D;
    public var projection:PerspectiveMatrix3D;

    // backing fields
    private var _x:Float = 0;
    private var _y:Float = 0;
    private var _z:Float = 0;
    private var _pitch:Float = 0;
    private var _yaw:Float = 0;
    private var _roll:Float = 0;
    private var _fov:Float;
    private var _aspect:Float;
    private var _near:Float;
    private var _far:Float;

    private var _dirtyView:Bool = true;
    private var _dirtyProj:Bool = true;

    public var x(get, set):Float;
    public var y(get, set):Float;
    public var z(get, set):Float;
    public var pitch(get, set):Float;
    public var yaw(get, set):Float;
    public var roll(get, set):Float;
    public var fov(get, set):Float;
    public var aspect(get, set):Float;
    public var near(get, set):Float;
    public var far(get, set):Float;

    public var alwaysDirty = false;

    public function new(fov:Float = 45, aspect:Float = 800/600, near:Float = 0.01, far:Float = 10000) {
        projection = new PerspectiveMatrix3D();
        view       = new Matrix3D();
        _fov    = fov;
        _aspect = aspect;
        _near   = near;
        _far    = far;
        updateProjection();
        updateView();
    }

    // getters / setters
    private function get_x():Float return _x;
    private function set_x(v:Float):Float { if(_x != v) { _x=v; _dirtyView=true;} return v; }
    private function get_y():Float return _y;
    private function set_y(v:Float):Float { if(_y != v) { _y=v; _dirtyView=true;} return v; }
    private function get_z():Float return _z;
    private function set_z(v:Float):Float { if(_z != v) { _z=v; _dirtyView=true;} return v; }
    private function get_pitch():Float return _pitch;
    private function set_pitch(v:Float):Float { if(_pitch != v) { _pitch=v; _dirtyView=true;} return v; }
    private function get_yaw():Float return _yaw;
    private function set_yaw(v:Float):Float { if(_yaw != v) { _yaw=v; _dirtyView=true;} return v; }
    private function get_roll():Float return _roll;
    private function set_roll(v:Float):Float { if(_roll != v) { _roll=v; _dirtyView=true;} return v; }
    private function get_fov():Float return _fov;
    private function set_fov(v:Float):Float { if(_fov != v) { _fov=v; _dirtyProj=true;} return v; }
    private function get_aspect():Float return _aspect;
    private function set_aspect(v:Float):Float { if(_aspect != v) { _aspect=v; _dirtyProj=true;} return v; }
    private function get_near():Float return _near;
    private function set_near(v:Float):Float { if(_near != v) { _near=v; _dirtyProj=true;} return v; }
    private function get_far():Float return _far;
    private function set_far(v:Float):Float { if(_far != v) { _far=v; _dirtyProj=true;} return v; }

    public var updateItterations = 0;

    public function updateMatrices():Void {
        if(_dirtyView || alwaysDirty) updateItterations++;

        if(_dirtyView || alwaysDirty) updateView();
        if(_dirtyProj || alwaysDirty) updateProjection();

        _dirtyView = _dirtyProj = false;
    }

    private function updateView():Void {
        // world matrix = R_yaw * R_pitch * R_roll * T(position)
        view.identity();
        view.appendRotation(_pitch, Vector3D.X_AXIS);
        view.appendRotation(_yaw,   Vector3D.Y_AXIS);
        view.appendRotation(_roll,  Vector3D.Z_AXIS);
        view.appendTranslation(_x, _y, _z);
        view.invert(); // view = (world)^-1
    }

    private function updateProjection():Void {
        //Debugger.log("Updating projection matrix", _fov, _aspect, _near, _far);
        projection.identity();
        projection.perspectiveFieldOfViewLH(_fov, _aspect, _near, _far);
    }

    public function lookAt(tx:Float, ty:Float, tz:Float):Void {
        // Compute direction vector
        var dx = tx - _x;
        var dy = ty - _y;
        var dz = tz - _z;
        // Calculate yaw: angle around Y-axis (left-handed), positive turns right
        // atan2(x, z): zero when looking along +Z
        yaw = Math.atan2(dx, dz) * Constants.RADIANS_TO_DEGREES;
        // Calculate pitch: angle around X-axis, positive looks down
        var horizontalDist = Math.sqrt(dx * dx + dz * dz);
        pitch = -Math.atan2(dy, horizontalDist) * Constants.RADIANS_TO_DEGREES;
        // Keep roll unchanged
        _dirtyView = true;
    }

    public function toString():String {
        return "Camera3D {" +
            "  x: " + _x + "," +
            "  y: " + _y + "," +
            "  z: " + _z + "," +
            "  pitch: " + _pitch + "," +
            "  yaw: " + _yaw + "," +
            "  roll: " + _roll + "," +
            "  fov: " + _fov + "," +
            "  aspect: " + _aspect + "," +
            "  near: " + _near + "," +
            "  far: " + _far + "," +
            "  dirtyView: " + _dirtyView + "," +
            "  dirtyProj: " + _dirtyProj + "" +
        "}";
    }
    
}