## The player, seen from above: walks in 8 directions, swings in the facing direction, carries one log. With the
## dash upgrade it can dash; with the spin upgrade every few swings go all the way round.
extends RefCounted

const Config := preload("res://src/sim/config.gd")
const P := Config.PLAYER

var pos: Vector2 = P.start
var vel := Vector2.ZERO
var face := Vector2.DOWN
var hp: int = P.hp
var invuln := 0.0
var hurt_t := 0.0
var dead := false
var attack_t := -1.0 # time into the swing, or -1 when not swinging
var swung := false
var carrying := false
var swings := 0 # swings started so far, for the spin upgrade
var spin := false # this swing goes all the way round
var dash_t := 0.0 # time left in a dash, or 0
var dash_wait := 0.0 # time until the next dash is ready
var dash_dir := Vector2.DOWN
var dropped = null # where the log you just put down lies, until you step off it; null otherwise


func step(world, inp) -> void:
	invuln = maxf(0.0, invuln - Config.STEP)
	dash_wait = maxf(0.0, dash_wait - Config.STEP)
	if dead:
		vel = Vector2.ZERO
	elif dash_t > 0.0:
		dash_t -= Config.STEP
		vel = dash_dir * P.dash_speed
	elif hurt_t > 0.0:
		hurt_t -= Config.STEP
	else:
		var dir := Vector2(
			(1.0 if inp.is_held("right") else 0.0) - (1.0 if inp.is_held("left") else 0.0),
			(1.0 if inp.is_held("down") else 0.0) - (1.0 if inp.is_held("up") else 0.0)).normalized()
		var slow: bool = carrying and not world.mod("carry_full", false)
		vel = dir * (P.carry_speed if slow else P.speed)
		if dir != Vector2.ZERO and attack_t < 0.0:
			face = dir
		var every: float = world.mod("dash_every", 0.0)
		if inp.is_pressed("dash") and every > 0.0 and dash_wait <= 0.0:
			dash_dir = dir if dir != Vector2.ZERO else face
			dash_t = P.dash_time
			dash_wait = every
			vel = dash_dir * P.dash_speed
		if inp.is_pressed("attack"):
			if carrying:
				carrying = false
				dropped = pos
				world.drop_log(pos)
			elif attack_t < 0.0:
				attack_t = 0.0
				swung = false
				face = world.aim(pos, face)
				swings += 1
				var spin_every: int = world.mod("spin_every", 0)
				spin = spin_every > 0 and swings % spin_every == 0
	if attack_t >= 0.0:
		attack_t += Config.STEP
		if not swung and attack_t >= P.attack_hit_at:
			swung = true
			world.melee(self)
		if attack_t >= P.attack_time:
			attack_t = -1.0
			spin = false
	pos = (pos + vel * Config.STEP).clamp(Config.FIELD.position, Config.FIELD.end)


## Take a hit from something at from_pos. Returns false while invulnerable, dashing or dead.
func hurt(from_pos: Vector2) -> bool:
	if invuln > 0.0 or dash_t > 0.0 or dead:
		return false
	hp -= 1
	invuln = P.invuln
	hurt_t = P.hurt_time
	vel = (pos - from_pos).normalized() * P.hurt_knock
	attack_t = -1.0
	spin = false
	if hp <= 0:
		dead = true
	return true
