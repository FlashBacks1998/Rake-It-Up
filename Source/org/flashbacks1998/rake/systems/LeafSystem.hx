package org.flashbacks1998.rake.systems;


import org.flashbacks1998.world3d.entity.Entity3D;

class LeafSystem {
  // -------- globals --------
  public static var windX:Float = 0.0;
  public static var windZ:Float = 0.0;

  public static var swayMultipleX:Float = 1.0;
  public static var swayMultipleY:Float = 0.0; // kept for API compat (unused in lite)
  public static var swayMultipleZ:Float = 1.0;

  static inline var GRAVITY:Float      = -10.0;
  static inline var TERMINAL_VEL:Float = -1.4;
  static inline var DRAG:Float         = 1.5;
  static inline var TWO_PI:Float       = 6.283185307179586;

  // -------- per-leaf --------
  public var _eRef:Entity3D;

  // vertical motion
  var _vy:Float = 0.0;

  // single oscillator
  var _theta:Float = 0.0; // phase (rad)
  var _omega:Float = 1.0; // angular speed (rad/s)

  // amplitudes (meters)
  var _ax:Float;
  var _az:Float;

  // fixed phase offsets per axis (precomputed sin/cos)
  var _sinPhiX:Float;
  var _cosPhiX:Float;
  var _sinPhiZ:Float;
  var _cosPhiZ:Float;

  // last-frame absolute sways (to apply delta)
  var _lastSwayX:Float = 0.0;
  var _lastSwayZ:Float = 0.0;

  // tumble (reuses oscillator)
  public var enableTumble:Bool = true;
  var _rollAmp:Float;
  var _pitchAmp:Float;
  var _yawAmp:Float;
  var _sinYawLead:Float; // sin(lead), precomputed
  var _cosYawLead:Float; // cos(lead), precomputed

  // ---- reusable temps (avoid repeated field lookups / math) ----
  var _tmpDX:Float = 0.0;
  var _tmpDZ:Float = 0.0;
  var _tmpWindX:Float = 0.0;
  var _tmpWindZ:Float = 0.0;

  public function new(eRef:Entity3D) {
    _eRef = eRef;

    inline function rr(a:Float, b:Float):Float return a + (b - a) * Math.random();
    inline function unit() return TWO_PI * Math.random();

    // amplitudes
    _ax = rr(0.12, 0.42);
    _az = rr(0.12, 0.42);

    // frequency → omega
    final f = rr(0.25, 0.85);
    _omega = TWO_PI * f;

    // per-axis phase offsets (precompute sin/cos)
    final phiX = unit();
    final phiZ = unit();
    _sinPhiX = Math.sin(phiX);
    _cosPhiX = Math.cos(phiX);
    _sinPhiZ = Math.sin(phiZ);
    _cosPhiZ = Math.cos(phiZ);

    // initial overall phase
    _theta = unit();

    // tumble parameters (degrees)
    _rollAmp  = rr(10.0, 28.0);
    _pitchAmp = rr( 8.0, 22.0);
    _yawAmp   = rr( 5.0, 18.0);

    // small yaw lead (rad) — store its sin/cos
    final yawLead = rr(0.4, 1.2);
    _sinYawLead = Math.sin(yawLead);
    _cosYawLead = Math.cos(yawLead);
  }

  public function update(dt:Float):Void {
    // ----- vertical physics -----
    final ay = GRAVITY - DRAG * _vy;
    _vy += ay * dt;
    if (_vy < TERMINAL_VEL) _vy = TERMINAL_VEL;

    // cache frequently used stuff
    final p = _eRef.position;     // single position reference
    _tmpWindX = windX * dt;
    _tmpWindZ = windZ * dt;

    // apply vertical first (cheaper writes while cache hot)
    p.y += _vy * dt;

    // ----- advance oscillator -----
    _theta += _omega * dt;
    if (_theta > TWO_PI) _theta -= TWO_PI; else if (_theta < -TWO_PI) _theta += TWO_PI;

    // compute sinθ/cosθ once
    final s = Math.sin(_theta);
    final c = Math.cos(_theta);

    // angle addition using precomputed sinφ/cosφ
    // X:  sin(θ+φx) = s*cosφx + c*sinφx
    final swayXAbs = _ax * (s * _cosPhiX + c * _sinPhiX);
    // Z:  cos(θ+φz) = c*cosφz - s*sinφz
    final swayZAbs = _az * (c * _cosPhiZ - s * _sinPhiZ);

    // deltas (no dt)
    _tmpDX = (swayXAbs - _lastSwayX) * swayMultipleX;
    _tmpDZ = (swayZAbs - _lastSwayZ) * swayMultipleZ;
    _lastSwayX = swayXAbs;
    _lastSwayZ = swayZAbs;

    // apply lateral + wind
    p.x += _tmpWindX + _tmpDX;
    p.z += _tmpWindZ + _tmpDZ;

    // ----- tumble (reuses s/c; zero extra trig) -----
    if (enableTumble) {
      // roll = A*sinθ
      // pitch = B*cosθ
      // yaw = C*sin(θ+lead) = C*(s*cosLead + c*sinLead)
      p.roll  = _rollAmp  * s;
      p.pitch = _pitchAmp * c;
      final sinYaw = s * _cosYawLead + c * _sinYawLead;
      p.yaw   = _yawAmp   * sinYaw;
    }
  }

  public inline function setPosition(x:Float, y:Float, z:Float):Void {
    final p = _eRef.position;
    p.x = x; p.y = y; p.z = z;
    _lastSwayX = 0.0; _lastSwayZ = 0.0; // avoid jump after teleport
  }

  public inline function setVerticalSpeed(vy:Float):Void { _vy = vy; }
  public inline function getVerticalSpeed():Float return _vy;
}
