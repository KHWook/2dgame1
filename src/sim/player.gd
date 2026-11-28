## The player, seen from above: walks in 8 directions with the keys (any of Config.STICK_DIRECTIONS with the touch
## stick), attacks in the facing direction (a swing, or an ember it shoots: its character's attack), carries logs (as
## many as its character can). With the dash upgrade it can dash; with the spin upgrade every few swings go all the
## way round (or, for a shooter, every few shots are a fan). Its numbers are Config.PLAYER with its character's
## stats over them (World.stats), handed in when it is made.
extends RefCounted

const Config := preload("res://src/sim/config.gd")

var P: Dictionary # its numbers: Config.PLAYER with its character's stats merged over
var pos: Vector2
var vel := Vector2.ZERO
var face := Vector2.DOWN
var hp: int
var invuln := 0.0
var invuln_for: float # how long a hit keeps it from the next one tonight (World.keeper_invuln())
var hurt_t := 0.0
var dead := false
var attack_t := -1.0 # time into the swing, or -1 when not swinging
var struck: Array = [] # the enemies this swing has hit: each is hit once per swing
var carrying := false # holding at least one log
var held := 0 # how many logs it holds, at most World.carry()
var swings := 0 # swings started so far, for the spin upgrade
var spin := false # this swing goes all the way round
var dash_t := 0.0 # time left in a dash, or 0
var dash_wait := 0.0 # time until the next dash is ready
var dash_dir := Vector2.DOWN
var dashed: Array = [] # the enemies this dash has hurt (World._trample): each once a dash
var dropped = null # where the log you just put down lies, until you step off it; null otherwise


func _init(stats: Dictionary = Config.PLAYER) -> void:
	P = stats
	pos = P.start
	hp = P.hp
	invuln_for = P.invuln


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
		if inp.stick >= 0: # the touch stick, at full speed whichever way it points
			dir = Vector2.from_angle(TAU * inp.stick / Config.STICK_DIRECTIONS)
		var slow: bool = carrying and not world.mod("carry_full", false)
		var lit: float = world.mod("lit_speed_mult", 1.0) if world.in_light(pos) else 1.0 # the bright fire upgrade
		var haste: float = world.mod("haste", 1.0) if world.time < world.haste_until else 1.0
		vel = dir * (carry_speed() if slow else P.speed) * lit * haste
		if dir != Vector2.ZERO and attack_t < 0.0:
			face = dir
		var every: float = world.mod("dash_every", 0.0)
		if inp.is_pressed("dash") and every > 0.0 and dash_wait <= 0.0:
			dash_dir = dir if dir != Vector2.ZERO else face
			dash_t = P.dash_time
			dash_wait = every
			dashed = []
			vel = dash_dir * P.dash_speed
		# swift's last level attacks by itself: ready, holding nothing, an enemy in reach (Config auto_attack)
		var auto: bool = attack_t < 0.0 and not carrying and world.mod("auto_attack", false) and world.foe_in_reach(pos)
		if inp.is_pressed("attack") or auto:
			if carrying: # every log held goes down where it stands, and the same press attacks
				for i in held:
					world.drop_log(pos)
				held = 0
				carrying = false
				dropped = pos
			if attack_t < 0.0:
				attack_t = 0.0
				struck = []
				face = world.aim(pos, face)
				swings += 1
				var spin_every: int = world.mod("spin_every", 0)
				spin = spin_every > 0 and swings % spin_every == 0
	if attack_t >= 0.0:
		var was := attack_t
		attack_t += Config.STEP
		var hit_at: float = world.stat("attack_hit_at") # its attack's times as the upgrades have them (swift)
		if P.attack == "shoot":
			if was < hit_at and attack_t >= hit_at:
				world.shoot(self)
		elif attack_t >= hit_at and attack_t <= world.stat("attack_hit_until"):
			world.melee(self)
		if attack_t >= world.stat("attack_time"):
			attack_t = -1.0
			spin = false
	pos = (pos + vel * Config.STEP).clamp(Config.FIELD.position, Config.FIELD.end)


## How fast it walks carrying what it holds: carry_speed with one log, carry_slow less for each more.
func carry_speed() -> float:
	return P.carry_speed - P.carry_slow * maxi(0, held - 1)


## Takes one more log into its arms. False when they are full: they hold most logs (World.carry()).
func take_log(most: int) -> bool:
	if held >= most:
		return false
	held += 1
	carrying = true
	return true


## Gives up one log (to a thief). False when it holds none.
func lose_log() -> bool:
	if held <= 0:
		return false
	held -= 1
	carrying = held > 0
	return true


## Take a hit from something at from_pos. Returns false while invulnerable, dashing or dead. It knocks you back and
## stuns you for a moment, but a swing already under way still lands.
func hurt(from_pos: Vector2) -> bool:
	if invuln > 0.0 or dash_t > 0.0 or dead:
		return false
	hp -= 1
	invuln = invuln_for
	hurt_t = P.hurt_time
	vel = (pos - from_pos).normalized() * P.hurt_knock # a swing under way goes on: the blow you started still lands
	if hp <= 0:
		dead = true
	return true
