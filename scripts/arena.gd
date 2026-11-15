class_name Arena
extends RefCounted
## Collision for the ball, read straight from the background picture:
## brown pixels are solid walls, green pixels are open sky.

const DEFAULT_BG: String = "res://art/background_clean.png"
const WORLD_SIZE: Vector2 = Vector2(1152, 648)

static var bg_path: String = DEFAULT_BG
## If not empty, these rectangles ARE the walls (the picture is ignored).
static var walls: Array[Rect2] = []
## If true, any StaticBody2D (with a CollisionShape2D) in the level is a wall.
static var use_physics_walls: bool = false
static var _mask: BitMap
static var _blur: PackedFloat32Array  # smoothed wall map, used for clean bounce directions
const BLUR_RADIUS: int = 6  # in picture pixels: bigger = smoother (flatter) wall surfaces
static var _size: Vector2i
static var _scale: Vector2


## Choose which picture the walls are read from (call once when a level starts).
static func set_background(path: String) -> void:
	walls = []
	use_physics_walls = false
	if path == bg_path and _mask != null:
		return
	bg_path = path
	_mask = null


## Use hand-placed rectangles as the walls instead of a picture.
static func set_walls(rects: Array[Rect2]) -> void:
	walls = rects
	use_physics_walls = false


## Walls are the StaticBody2D nodes you place in the level scene.
static func set_physics_walls() -> void:
	walls = []
	use_physics_walls = true


static func _ensure() -> void:
	if _mask != null:
		return
	var tex: Texture2D = load(bg_path)
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	_size = img.get_size()
	_scale = WORLD_SIZE / Vector2(_size)
	_mask = BitMap.new()
	_mask.create(_size)
	for y in _size.y:
		for x in _size.x:
			var c: Color = img.get_pixel(x, y)
			_mask.set_bit(x, y, c.r > c.g + 0.03)
	_build_blur()


## Blurs the wall map so the wobbly pixel edges of the picture become smooth surfaces.
static func _build_blur() -> void:
	var w: int = _size.x
	var h: int = _size.y
	var a: PackedFloat32Array = PackedFloat32Array()
	a.resize(w * h)
	for y in h:
		for x in w:
			a[y * w + x] = 1.0 if _mask.get_bit(x, y) else 0.0
	var tmp: PackedFloat32Array = PackedFloat32Array()
	tmp.resize(w * h)
	_blur = PackedFloat32Array()
	_blur.resize(w * h)
	var r: int = BLUR_RADIUS
	var cnt: float = 2.0 * r + 1.0
	for y in h:  # horizontal pass, running sum (outside the picture counts as wall)
		var row: int = y * w
		var s: float = float(r)  # the r columns left of the picture
		for k in range(0, r + 1):
			s += a[row + k] if k < w else 1.0
		for x in w:
			tmp[row + x] = s / cnt
			var add: int = x + r + 1
			var sub: int = x - r
			s += (a[row + add] if add < w else 1.0) - (a[row + sub] if sub >= 0 else 1.0)
	for x in w:  # vertical pass
		var s: float = float(r)
		for k in range(0, r + 1):
			s += tmp[k * w + x] if k < h else 1.0
		for y in h:
			_blur[y * w + x] = s / cnt
			var add: int = y + r + 1
			var sub: int = y - r
			s += (tmp[add * w + x] if add < h else 1.0) - (tmp[sub * w + x] if sub >= 0 else 1.0)


static func _blur_at(x: int, y: int) -> float:
	if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
		return 1.0
	return _blur[y * _size.x + x]


## Smooth surface normal (pointing into open space) near world point p.
static func _smooth_normal(p: Vector2) -> Vector2:
	var x: int = floori(p.x / _scale.x)
	var y: int = floori(p.y / _scale.y)
	var d: int = 2
	var g: Vector2 = Vector2(
		_blur_at(x + d, y) - _blur_at(x - d, y),
		_blur_at(x, y + d) - _blur_at(x, y - d))
	return -g  # the gradient points into the wall, so flip it


static func is_solid(p: Vector2) -> bool:
	if use_physics_walls:
		if p.x < 0.0 or p.y < 0.0 or p.x >= WORLD_SIZE.x or p.y >= WORLD_SIZE.y:
			return true
		var root: Window = (Engine.get_main_loop() as SceneTree).root
		var q: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		q.position = p
		q.collide_with_areas = true  # barriers made as Area2D count too
		for hit in root.world_2d.direct_space_state.intersect_point(q, 16):
			var c: Object = hit["collider"]
			if not (c.is_in_group("ball") or c.is_in_group("ghost") or c.is_in_group("pickup")):  # ball / enemies / coins are not walls
				return true
		return false
	if not walls.is_empty():
		if p.x < 0.0 or p.y < 0.0 or p.x >= WORLD_SIZE.x or p.y >= WORLD_SIZE.y:
			return true
		for r in walls:
			if r.has_point(p):
				return true
		return false
	_ensure()
	var x: int = floori(p.x / _scale.x)
	var y: int = floori(p.y / _scale.y)
	if x < 0 or y < 0 or x >= _size.x or y >= _size.y:
		return true
	return _mask.get_bit(x, y)


## Surface normal (pointing into open space) if a circle at p touches a wall,
## otherwise Vector2.ZERO.
static func wall_normal(p: Vector2, r: float, travel: Vector2) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	var contact: Vector2 = Vector2.ZERO
	var touching: int = 0
	var hit: bool = is_solid(p)
	for i in 24:
		var dir: Vector2 = Vector2.from_angle(TAU * i / 24.0)
		if is_solid(p + dir * r):
			hit = true
			sum -= dir
			contact += p + dir * r
			touching += 1
	if not hit:
		return Vector2.ZERO
	# Picture walls: use the smoothed surface direction at the touching point.
	if touching > 0 and walls.is_empty() and not use_physics_walls:
		var sn: Vector2 = _smooth_normal(contact / touching)
		if sn.length() > 0.02:
			return sn.normalized()
	if sum.length() < 0.01:
		return -travel.normalized()
	return sum.normalized()


## Moves a circle for dt seconds, bouncing off walls.
## Returns {"pos": Vector2, "vel": Vector2, "bounced": bool}.
static func move(pos: Vector2, vel: Vector2, dt: float, r: float) -> Dictionary:
	var bounced: bool = false
	var steps: int = maxi(1, ceili(vel.length() * dt / 3.0))
	var h: float = dt / steps
	for i in steps:
		var next: Vector2 = pos + vel * h
		var n: Vector2 = wall_normal(next, r, vel)
		if n == Vector2.ZERO:
			pos = next
		elif vel.dot(n) < 0.0:
			vel = vel.bounce(n)
			bounced = true
		else:
			pos = next  # already moving away from the wall
	return {"pos": pos, "vel": vel, "bounced": bounced}
