## The player, seen from above: walks in 8 directions, swings in the facing direction, carries one log.
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
var dropped = null # where the log you just put down lies, until you step off it; null otherwise


func step(world, inp) -> void:
	invuln = maxf(0.0, invuln - Config.STEP)
	if dead:
		vel = Vector2.ZERO
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
		if inp.is_pressed("attack"):
			if carrying:
				carrying = false
				dropped = pos
				world.drop_log(pos)
			elif attack_t < 0.0:
				attack_t = 0.0
				swung = false
				face = world.aim(pos, face)
	if attack_t >= 0.0:
		attack_t += Config.STEP
		if not swung and attack_t >= P.attack_hit_at:
			swung = true
			world.melee(self)
		if attack_t >= P.attack_time:
			attack_t = -1.0
	pos = (pos + vel * Config.STEP).clamp(Config.FIELD.position, Config.FIELD.end)


## Take a hit from something at from_pos. Returns false while invulnerable or dead.
func hurt(from_pos: Vector2) -> bool:
	if invuln > 0.0 or dead:
		return false
	hp -= 1
	invuln = P.invuln
	hurt_t = P.hurt_time
	vel = (pos - from_pos).normalized() * P.hurt_knock
	attack_t = -1.0
	if hp <= 0:
		dead = true
	return true
