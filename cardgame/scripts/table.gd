class_name Table
extends Control

signal player_win
signal player_fail

var _have_ace: bool = false
var player_turn: bool = false
var player_score: int = 0
var enemy_score: int = 0
#TODO maybe have 2 different enemy scenes?
var enemy_count: int = 1
var end_scene = preload("res://ui/end_screen.tscn")
var player_win_instance
var player_fail_instance
var game_over: bool = false

@onready var player:Player = $MainLayout/PlayerBox/Player
@onready var enemy:Enemy = $MainLayout/EnemyBox/Enemy
@onready var hit_button: Button = $MainLayout/CenterLayout/HitButton
@onready var stand_button: Button = $MainLayout/CenterLayout/StandButton
@onready var background = $TextureRect
@onready var enemy_stand_label: Label = $EnemyStandLabel
@onready var compare = $TileMap/TextureRect
@onready var tips = $TipLabel
@onready var player_win_screen = preload("res://ui/player_win_screen.tscn")
@onready var player_fail_screen = preload("res://ui/player_fail_screen.tscn")
@onready var button_disabled_timer = Timer.new()


func _ready():
	#background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(button_disabled_timer)
	button_disabled_timer.one_shot = true
	
	player_win_instance = player_win_screen.instantiate()
	add_child(player_win_instance)
	player_win_instance.hide()
	player_win_instance.layer = 0
	
	player_fail_instance = player_fail_screen.instantiate()
	add_child(player_fail_instance)
	player_fail_instance.hide()
	player_fail_instance.layer = 0
	
	# initialize and start
	enemy.status_card.update_max(50)
	enemy.status_card.update_hp(50)
	_start_round()
	
	# Hide the tips
	await get_tree().create_timer(5).timeout
	tips.hide()

	
func _process(delta: float) -> void:
	if !player_turn:
		hit_button.disabled = true
		stand_button.disabled = true
	else:
		if !button_disabled_timer.is_stopped():
			hit_button.disabled = true
			stand_button.disabled = true
		else:
			hit_button.disabled = false
			stand_button.disabled = false
	
	if enemy.is_stopped and enemy.score_card.current_score <= enemy.score_card.max_score:
		enemy_stand_label.visible = true
	else:
		enemy_stand_label.visible = false
		
	if (player.status_card.current_hp <= 0 or enemy.status_card.current_hp <= 0) and not game_over:
		game_over = true
		final_winner()
	

func _start_round():
	# enemy first turn
	enemy.decide_action(enemy,player)
	enemy_score = calculate_score(enemy, enemy.displayed_cards.cards, enemy.score_card.max_score)
	enemy.score_card.update_score(enemy_score)
	player_turn = true
	enemy_stand_label.visible = false
	
func _on_hit_button_pressed() -> void:
	if enemy.is_stopped:
		_disable_buttons_for_2_seconds()
	if player_turn and player_score < player.score_card.max_score:
		SoundManager.play_sfx("ButtonStart")
		player.draw_and_execute_card(player, enemy)
		player_score = calculate_score(player, player.displayed_cards.cards, player.score_card.max_score)
		player.score_card.update_score(player_score)
		if player_score >= player.score_card.max_score:
			player.is_stopped = true
			if enemy.is_stopped:
				check_winner()
			else:
				player_turn = false
				enemy_turn()
		else:
			if !enemy.is_stopped:
				player_turn = false
				enemy_turn()

func _on_stand_button_pressed() -> void:
	#player_score = calculate_score(player.displayed_cards.cards, player.score_card.max_score)
	#TODO: need to get max score
	if player_turn and player_score < player.score_card.max_score:
		SoundManager.play_sfx("ButtonStart")
		player.is_stopped = true
		if !enemy.is_stopped:
			player_turn = false
			enemy_turn()
		else:
			check_winner()

# buttons
func _on_hit_button_button_down() -> void:
	hit_button.icon = preload("res://assets/table/hit_button_pressed.png")

func _on_hit_button_button_up() -> void:
	hit_button.icon = preload("res://assets/table/hit_button.png")

func _on_stand_button_button_down() -> void:
	stand_button.icon = preload("res://assets/table/stand_button_pressed.png")

func _on_stand_button_button_up() -> void:
	stand_button.icon = preload("res://assets/table/stand_button.png")

func _player_win():
	print("Enemy defeated!")
	SoundManager.play_sfx("game_win")
	#TODO beat enemy animation
	enemy_count -= 1
	if enemy_count != 0:
		load_new_enemy()
	else:
		print("Player defeated all enemies! Victory!")
		# victory scene
	
func _enemy_win():
	print("Player lost!")
	# player lose scene

func _disable_buttons_for_2_seconds():
	hit_button.disabled = true
	stand_button.disabled = true
	button_disabled_timer.start(2.0)

func check_winner() -> void:
	player_turn = false
	player_score = calculate_score(player, player.displayed_cards.cards, player.score_card.max_score)
	player.score_card.update_score(player_score)
	enemy_score = calculate_score(enemy, enemy.displayed_cards.cards, enemy.score_card.max_score)
	enemy.score_card.update_score(enemy_score)
	var score_difference = player_score - enemy_score
	var damage: int = 0
	var player_win: bool
	# same score or both bust
	if score_difference == 0 or (player_score > player.score_card.max_score and enemy_score > enemy.score_card.max_score):
		#TODO: tie animation
		compare.texture = load("res://assets/table/tie.png")
		pass
	# only enemy bust
	elif enemy_score > enemy.score_card.max_score:
		compare.texture = load("res://assets/table/win.png")
		player_win = true
		damage = suit_execute(player_score, player_win, player_score)
		enemy.modify_health(-damage)
		$EnemyHpChange.text = "-" + str(damage)
	# only player bust
	elif player_score > player.score_card.max_score:
		compare.texture = load("res://assets/table/lose.png")
		player_win = false
		damage = suit_execute(-enemy_score, player_win, player_score)
		player.modify_health(damage)
		$PlayerHpChange.text = str(damage)
	# both didn't bust
	else:
		# player win
		if score_difference > 0:
			compare.texture = load("res://assets/table/win.png")
			player_win = true
			damage = suit_execute(score_difference, player_win, player_score)
			enemy.modify_health(-damage)
			$EnemyHpChange.text = "-" + str(damage)
		# enemy win
		else:
			compare.texture = load("res://assets/table/lose.png")
			player_win = false
			damage = suit_execute(score_difference, player_win, player_score)
			player.modify_health(damage)
			$PlayerHpChange.text = str(damage)
	# check signals
	enemy.enemy_died.connect(_player_win)
	player.player_died.connect(_enemy_win)
	await get_tree().create_timer(2).timeout
	# reset round
	round_done()
	
func calculate_score(controller:Controller, hand: Array, max_score: int) -> int:
	var score: int = 0
	# Calculate the total score logic
	for card in hand:
		score += card.score
		if card.score == 11:
			_have_ace = true
	score += controller.extra_points
	# Ace logic
	if _have_ace and score > max_score:
		score -= 10
	return score

func enemy_turn():
	await get_tree().create_timer(2).timeout
	while !player_turn and !enemy.is_stopped:
		#enemy.card_deck.texture = load("res://assets/cards/card_back_1.png")
		enemy.decide_action(enemy, player)
		enemy_score = calculate_score(enemy,enemy.displayed_cards.cards, enemy.score_card.max_score)
		enemy.score_card.update_score(enemy_score)
		if enemy_score >= enemy.score_card.max_score:
			enemy.is_stopped = true
		if !player.is_stopped or enemy.is_stopped:
			player_turn = true
	if player.is_stopped and enemy.is_stopped:
		check_winner()
	else:
		enemy_score = calculate_score(enemy, enemy.displayed_cards.cards, enemy.score_card.max_score)
		enemy.score_card.update_score(enemy_score)
		player_score = calculate_score(player, player.displayed_cards.cards, player.score_card.max_score)
		player.score_card.update_score(player_score)


func round_done():
		player.reset_turn()
		enemy.reset_turn()
		$EnemyHpChange.text = ""
		$PlayerHpChange.text = ""
		await get_tree().create_timer(2).timeout
		player_score = 0
		enemy_score = 0
		compare.texture = null
		enemy.decide_action(enemy, player)
		enemy_score = calculate_score(enemy, enemy.displayed_cards.cards, enemy.score_card.max_score)
		enemy.score_card.update_score(enemy_score)
		player_turn = true
		_have_ace = false
		player.extra_points = 0
		enemy.extra_points = 0


# Check final winner
func final_winner():
	# Player lost
	SoundManager.has_stop_all_called = false
	SoundManager.stop_all() 
	SoundManager.has_stop_all_called = true
	print(enemy.status_card.current_hp)
	if enemy.status_card.current_hp == 0:
		SoundManager.play_sfx("PlayerWinBGM")
		await get_tree().create_timer(2).timeout
		player_win_instance.show()
		player_win_instance.layer = 99
		player_win_instance.start_animation()
		await get_tree().create_timer(2).timeout
		
	# Player win
	if player.status_card.current_hp == 0:
		SoundManager.play_sfx("PlayerFailBGM")
		await get_tree().create_timer(2).timeout
		player_fail_instance.show()
		player_fail_instance.layer = 99
		player_fail_instance.start_animation()
		await get_tree().create_timer(2).timeout
	
	
## multiple enemy logic
func load_new_enemy() -> void:
	if enemy:
		enemy.queue_free() # Remove the existing enemy
		var new_enemy = preload("res://scenes/enemy.tscn").instance() # Load and instance a new enemy
		var parent = $MainLayout/EnemyBox
		parent.add_child(new_enemy)
		new_enemy.name = "Enemy" # Optional: Rename to match original
		print("Enemy replaced successfully")
		_start_round()
	
	
func suit_execute(damage: int, win: bool, score: int) -> int:
	var suit = GameGlobal.chosen_suit
	var new_damage: int
	match suit:
		GameGlobal.Suit.CLUBS:
			if win:
				new_damage = ceil(damage * 1.5)
			else:
				new_damage = damage
		GameGlobal.Suit.DIAMONDS:
			if win and score == player.score_card.max_score:
				new_damage = player.score_card.max_score
				player.modify_health(player.score_card.max_score)
				$PlayerHpChange.text = "+" + str(player.score_card.max_score)
			else:
				new_damage = damage
		GameGlobal.Suit.HEARTS:
			if player_win:
				player.modify_health(damage/2)
				$PlayerHpChange.text = "+" + str(damage/2)
			new_damage = damage
		GameGlobal.Suit.SPADES:
			if win and score == player.score_card.max_score:
				new_damage = damage * 2
			else:
				new_damage = damage
	return new_damage
	

func _on_button_pressed() -> void:
	player.modify_health(-100)
