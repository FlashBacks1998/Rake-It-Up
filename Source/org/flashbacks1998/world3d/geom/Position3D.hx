package org.flashbacks1998.world3d.geom;

import org.flashbacks1998.world3d.util.Constants;
import openfl.geom.Matrix3D;

class Position3D extends Matrix3D {
	// Backing fields for properties.
	private var _x:Float = 0;
	private var _y:Float = 0;
	private var _z:Float = 0;
	private var _pitch:Float = 0;
	private var _yaw:Float = 0;
	private var _roll:Float = 0;

	// Backing fields for scaling.
	private var _scaleX:Float = 1;
	private var _scaleY:Float = 1;
	private var _scaleZ:Float = 1;

	// Public properties with custom getters and setters.
	public var x(get, set):Float;
	public var y(get, set):Float;
	public var z(get, set):Float;
	public var pitch(get, set):Float;
	public var yaw(get, set):Float;
	public var roll(get, set):Float;
	public var scaleX(get, set):Float;
	public var scaleY(get, set):Float;
	public var scaleZ(get, set):Float;

	private var toUpdate = true;
	public var locked = false;
    public var updateItterations = 0;

	public function new(?x:Float, ?y:Float, ?z:Float, ?pitch:Float, ?yaw:Float, ?roll:Float) {
		super();
		identity();

		this.x = x ?? 0;
		this.y = y ?? 0;
		this.z = z ?? 0;
		this.pitch = pitch ?? 0;
		this.yaw = yaw ?? 0;
		this.roll = roll ?? 0;
	}

	// x property.
	private function get_x():Float {
		return _x;
	}

	private function set_x(value:Float):Float {
		_x = value;
		toUpdate = true;
		return value;
	}

	// y property.
	private function get_y():Float {
		return _y;
	}

	private function set_y(value:Float):Float {
		_y = value;
		toUpdate = true;
		return value;
	}

	// z property.
	private function get_z():Float {
		return _z;
	}

	private function set_z(value:Float):Float {
		_z = value;
		toUpdate = true;
		return value;
	}

	// pitch property.
	private function get_pitch():Float {
		return _pitch;
	}

	private function set_pitch(value:Float):Float {
		_pitch = value;
		toUpdate = true;
		return value;
	}

	// yaw property.
	private function get_yaw():Float {
		return _yaw;
	}

	private function set_yaw(value:Float):Float {
		_yaw = value;
		toUpdate = true;
		return value;
	}

	// roll property.
	private function get_roll():Float {
		return _roll;
	}

	private function set_roll(value:Float):Float {
		_roll = value;
		toUpdate = true;
		return value;
	}

	// scaleX property.
	private function get_scaleX():Float {
		return _scaleX;
	}

	private function set_scaleX(value:Float):Float {
		_scaleX = value;
		toUpdate = true;
		return value;
	}

	// scaleY property.
	private function get_scaleY():Float {
		return _scaleY;
	}

	private function set_scaleY(value:Float):Float {
		_scaleY = value;
		toUpdate = true;
		return value;
	}

	// scaleZ property.
	private function get_scaleZ():Float {
		return _scaleZ;
	}

	private function set_scaleZ(value:Float):Float {
		_scaleZ = value;
		toUpdate = true;
		return value;
	}

	/**
	 * Rebuilds the object's transformation matrix.
	 * Applies scaling, then rotations (roll, pitch, yaw), and finally translation.
	 */
	public function updateMatrix():Void {
		if (locked)
			return;

		if (!toUpdate)
			return;

		updateItterations++;

		toUpdate = false;
		super.identity();

		//trace([x, y, z, roll, pitch, yaw, scaleX, scaleY, scaleZ]);

		// 1) scale
		appendScale(_scaleX, _scaleY, _scaleZ);
		// 2) rotate
		appendRotation(_roll, Constants.VECTOR3D_POSZ);
		appendRotation(_pitch, Constants.VECTOR3D_POSX);
		appendRotation(_yaw, Constants.VECTOR3D_POSY);
		// 3) translate
		appendTranslation(_x, _y, _z);
	}

	override public function identity():Void {
		super.identity();

		// Reset the Position3D properties.
		_x = 0;
		_y = 0;
		_z = 0;
		_pitch = 0;
		_yaw = 0;
		_roll = 0;
		_scaleX = 1;
		_scaleY = 1;
		_scaleZ = 1;

		toUpdate = false;
	}

	public function copyToPosition3D(target:Position3D):Void {
		target.x = this._x;
		target.y = this._y;
		target.z = this._z;
		target.pitch = this._pitch;
		target.yaw = this._yaw;
		target.roll = this._roll;
		target.scaleX = this._scaleX;
		target.scaleY = this._scaleY;
		target.scaleZ = this._scaleZ;
	}

	public function appendPosition3D(pos:Position3D):Position3D {
		this._x += pos.x;
		this._y += pos.y;
		this._z += pos.z;
		this._pitch += pos.pitch;
		this._yaw += pos.yaw;
		this._roll += pos.roll;
		this._scaleX *= pos.scaleX;
		this._scaleY *= pos.scaleY;
		this._scaleZ *= pos.scaleZ;
		toUpdate = true;
		return this;
	}

	public function clonePosition3D():Position3D {
		var copy = new Position3D();
		copy.x = this.x;
		copy.y = this.y;
		copy.z = this.z;
		copy.pitch = this.pitch;
		copy.yaw = this.yaw;
		copy.roll = this.roll;
		copy.scaleX = this.scaleX;
		copy.scaleY = this.scaleY;
		copy.scaleZ = this.scaleZ;
		return copy;
	}

	public function copyFromPosition3D(position:Position3D):Void {
		_x = position.x;
		_y = position.y;
		_z = position.z;
		_pitch = position.pitch;
		_yaw = position.yaw;
		_roll = position.roll;
		_scaleX = position.scaleX;
		_scaleY = position.scaleY;
		_scaleZ = position.scaleZ;
		toUpdate = true;
	}

	public function lookAt(x:Float, y:Float, z:Float):Void {
		// 1) Direction vector from eye to target
		final dx:Float = x - _x;
		final dy:Float = y - _y;
		final dz:Float = z - _z;

		// 2) Yaw  = horizontal angle around Y‑axis
		//    atan2(x, z) gives bearing in radians
		_yaw = Math.atan2(dx, dz) * Constants.RADIANS_TO_DEGREES;

		// 3) Pitch = vertical angle around local X‑axis
		//    sqrt(dx² + dz²) is horizontal distance
		_pitch = Math.atan2(dy, Math.sqrt(dx * dx + dz * dz)) * Constants.RADIANS_TO_DEGREES;

		// 4) Roll = 0 (no banking)
		_roll = 0;

		// Mark matrix dirty so next updateMatrix() rebuilds it
		toUpdate = true;
	}

	/**
	 * Reads a full Matrix3D (including scale, rotation, translation)
	 * and sets this Position3D’s x,y,z, scaleX/Y/Z and roll/pitch/yaw
	 * so that updateMatrix() would re‑make that same transform.
	 */
     public static function fromMatrix(m:Matrix3D):Position3D {
        // grab rawData once
        final d = m.rawData;

        // create the result
        final out = new Position3D();

        // 1) translation
        out._x = d[12];
        out._y = d[13];
        out._z = d[14];

        // 2) scale
        var sx = Math.sqrt(d[0]*d[0] + d[1]*d[1] + d[2]*d[2]);
        var sy = Math.sqrt(d[4]*d[4] + d[5]*d[5] + d[6]*d[6]);
        var sz = Math.sqrt(d[8]*d[8] + d[9]*d[9] + d[10]*d[10]);
        out._scaleX = sx;
        out._scaleY = sy;
        out._scaleZ = sz;

        // avoid degenerate
        if (sx == 0 || sy == 0 || sz == 0) {
            out._roll = 0;
            out._pitch = 0;
            out._yaw = 0;
            out.toUpdate = false;
            return out;
        }

        // 3) normalized rotation basis
        var r00 = d[0]  / sx;  var r01 = d[4]  / sy;  var r02 = d[8]  / sz;
        var r10 = d[1]  / sx;  var r11 = d[5]  / sy;  var r12 = d[9]  / sz;
        var r20 = d[2]  / sx;  var r21 = d[6]  / sy;  var r22 = d[10] / sz;

        // 4) Euler Z‑X‑Y
        out._pitch = Math.asin(-r21) * Constants.RADIANS_TO_DEGREES;
        if (Math.abs(r21) < 0.99999) {
            out._roll =  Math.atan2(r01, r11) * Constants.RADIANS_TO_DEGREES;
            out._yaw  =  Math.atan2(r20, r22) * Constants.RADIANS_TO_DEGREES;
        } else {
            out._roll = 0;
            out._yaw  =  Math.atan2(-r02, r00) * Constants.RADIANS_TO_DEGREES;
        }

        out.toUpdate = false;
        return out;
    }

	public function setTo(x,y,z) {
		this._x = x;
		this._y = y;
		this._z = z;

		toUpdate = true;
	}
    
	public function toString():String {
		// Make sure any pending matrix updates are applied if you rely on them elsewhere:
		// updateMatrix();

		return [
			"Position3D(",
			"x=" + Std.string(_x),
			", y=" + Std.string(_y),
			", z=" + Std.string(_z),
			", pitch=" + Std.string(_pitch),
			", yaw=" + Std.string(_yaw),
			", roll=" + Std.string(_roll),
			", scaleX=" + Std.string(_scaleX),
			", scaleY=" + Std.string(_scaleY),
			", scaleZ=" + Std.string(_scaleZ),
			")"
		].join("");
	}
}
