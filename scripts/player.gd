extends CharacterBody2D

const SPEED = 130
const JUMP_VELOCITY = -260
const GRAVITY = 400
const AIR_CONTROL_FACTOR = 0.5
const DUCK_SPEED = 0.2
const FRICTION = 800
const JUMP_CUTOFF = -100
const JUMP_COOLDOWN = 0.1
const COYOTE_TIME = 0.15
const FALL_SPEED_MULTIPLIER_WHILE_DUCKING = 1.5

const DASH_SPEED = 300  # Speed during dash
const DASH_TIME = 0.2   # How long the dash lasts
const DASH_COOLDOWN = 0.5
const DASH_DECAY_TIME = 0.1  # Time for speed decay at the end of the dash
const DASH_GRACE_PERIOD = 0.3  # Time to allow direction change at start


# Define the intensity and duration of the screen shake when dashing
const SHAKE_DURATION = 0.2
const SHAKE_INTENSITY = 3.0



@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var standing_hitbox: CollisionShape2D = $CollisionShape2D
@onready var ducking_hitbox: CollisionShape2D = $CollisionShapeDuck
@onready var camera_2d: Camera2D = $Camera2D
var shake_intensity = 0.0  # Variable to track shake intensity
var shake_timer = 0.0      # Timer to control shake duration

var dash_timer = 0.0  # Timer for how long the dash lasts
var dash_cooldown = 0.0  # Timer to prevent dashing during cooldown
var dash_direction = Vector2.ZERO  # Direction of the dash
var is_dashing = false
var MAX_dashes = 1
var dashes = 0
var last_direction = Vector2(1, 0)  # Track last direction the player was moving (default right)

var jump_timer = 0.0
var coyote_timer = 0.0


func _physics_process(delta: float) -> void:
	# Update timers
	jump_timer -= delta
	coyote_timer -= delta
	dash_timer -= delta
	dash_cooldown -= delta
	shake_timer -= delta  # Update shake timer

	# Apply screen shake if shake_timer is active
	if shake_timer > 0.0:
		apply_screen_shake()

	# Reset camera offset when shake ends
	if shake_timer <= 0.0 and camera_2d.offset != Vector2.ZERO:
		camera_2d.offset = Vector2.ZERO

	# Add gravity if not dashing
	if not is_on_floor() and not is_dashing:
		if Input.is_action_pressed("ui_down"):
			velocity.y += GRAVITY * FALL_SPEED_MULTIPLIER_WHILE_DUCKING * delta
		else:
			velocity.y += GRAVITY * delta
	elif is_on_floor():
		coyote_timer = COYOTE_TIME

	# Reset dashes when grounded
	if is_on_floor():
		dashes = MAX_dashes
	
	# Handle dash input
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and dashes > 0:
		start_dash()

	# If dashing, maintain or decay dash speed
	if is_dashing:
		if dash_timer > 0:
			handle_dash(delta)
		else:
			stop_dash(delta)

	# Add gravity if not dashing
	if not is_on_floor() and not is_dashing:
		if Input.is_action_pressed("ui_down"):
			velocity.y += GRAVITY * FALL_SPEED_MULTIPLIER_WHILE_DUCKING * delta
		else:
			velocity.y += GRAVITY * delta
	elif is_on_floor():
		coyote_timer = COYOTE_TIME

	# Reset dashes when grounded
	if is_on_floor():
		dashes = MAX_dashes
	
	# Handle dash input
	if Input.is_action_just_pressed("dash") and dash_cooldown <= 0 and dashes > 0:
		start_dash()

	# If dashing, maintain or decay dash speed
	if is_dashing:
		if dash_timer > 0:
			handle_dash(delta)
		else:
			stop_dash(delta)

	# Handle jump, considering coyote time and jump cooldown
	if Input.is_action_just_pressed("Jump") and (is_on_floor() or coyote_timer > 0) and jump_timer <= 0 and not is_dashing:
		velocity.y = JUMP_VELOCITY
		jump_timer = JUMP_COOLDOWN
	elif Input.is_action_just_released("Jump") and velocity.y < JUMP_CUTOFF:
		velocity.y = JUMP_CUTOFF

	# Handle ducking input
	var duck = Input.is_action_pressed("ui_down")
	var direction = Input.get_axis("ui_left", "ui_right")

	# Flip the sprite based on direction and track last direction
	if direction > 0:
		animated_sprite_2d.flip_h = false
		last_direction = Vector2(1, 0)  # Moving right
	elif direction < 0:
		animated_sprite_2d.flip_h = true
		last_direction = Vector2(-1, 0)  # Moving left

	# Handle movement, only if not dashing
	if not is_dashing:
		if duck and is_on_floor():
			var collision = move_and_collide(Vector2(0, 1))
			if collision:
				velocity.x = direction * DUCK_SPEED
				animated_sprite_2d.play("Duck")
			else:
				velocity.x = 0
		else:
			if direction != 0:
				velocity.x = direction * SPEED
				animated_sprite_2d.play("Walk")
			else:
				if velocity.x > 0:
					velocity.x = max(velocity.x - FRICTION * delta, 0)
				elif velocity.x < 0:
					velocity.x = min(velocity.x + FRICTION * delta, 0)

			if not is_on_floor():
				animated_sprite_2d.play("Jump")
			elif direction == 0 and not duck:
				animated_sprite_2d.play("Idle")
	
	# Bounce back to original size when the character lands or is idle
	if is_on_floor() and not is_dashing and velocity.y == 0:
		animated_sprite_2d.scale.x = lerp(animated_sprite_2d.scale.x, 1.0, 0.1)
		animated_sprite_2d.scale.y = lerp(animated_sprite_2d.scale.y, 1.0, 0.1)

	# Use move_and_slide to apply movement
	move_and_slide()


# Start the dash
func start_dash() -> void:
	is_dashing = true
	dash_timer = DASH_TIME
	dash_direction = Vector2(
		Input.get_axis("ui_left", "ui_right"),
		Input.get_axis("ui_up", "ui_down")
	)

	# If no input is detected, use last direction as default
	if dash_direction == Vector2.ZERO:
		dash_direction = last_direction
	dash_cooldown = DASH_COOLDOWN
	dash_timer = DASH_TIME
	velocity.y = 0  # Cancel vertical movement
	dashes -= 1


	# Trigger screen shake
	start_screen_shake()


# Handle the dash while in motion
func handle_dash(_delta: float) -> void:
	# Allow changing direction during grace period
	if dash_timer > DASH_TIME - DASH_GRACE_PERIOD:
		var new_direction = Vector2(
			Input.get_axis("ui_left", "ui_right"),
			Input.get_axis("ui_up", "ui_down")
		)
		if new_direction != Vector2.ZERO:
			dash_direction = new_direction.normalized()
	Engine.time_scale = 0.1
	wait(1)
	Engine.time_scale = 1
	# Maintain dash speed
	velocity = dash_direction * DASH_SPEED

	# Subtle squish/stretch effect during the dash
	animated_sprite_2d.scale.x = lerp(animated_sprite_2d.scale.x, 1.1, 0.2)
	animated_sprite_2d.scale.y = lerp(animated_sprite_2d.scale.y, 0.9, 0.2)


# End the dash and return to normal size
func stop_dash(_delta: float) -> void:
	is_dashing = false
	
	# Gradually reduce velocity after dash
	if abs(velocity.x) > 0:
		velocity.x = lerp(velocity.x, 0.0, DASH_DECAY_TIME / DASH_TIME)
	if abs(velocity.y) > 0:
		velocity.y = lerp(velocity.y, 0.0, DASH_DECAY_TIME / DASH_TIME)

	# Bounce back to original size
	animated_sprite_2d.scale.x = lerp(animated_sprite_2d.scale.x, 1.0, 0.2)
	animated_sprite_2d.scale.y = lerp(animated_sprite_2d.scale.y, 1.0, 0.2)


# Start screen shake
func start_screen_shake() -> void:
	shake_intensity = SHAKE_INTENSITY
	shake_timer = SHAKE_DURATION


# Apply screen shake effect
func apply_screen_shake() -> void:
	var shake_offset = Vector2(
		randf_range(-shake_intensity, shake_intensity),
		randf_range(-shake_intensity, shake_intensity)
	)
	camera_2d.offset = shake_offset
	shake_intensity = lerp(shake_intensity, 0.0, 0.1)  # Gradually reduce shake intensity


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
