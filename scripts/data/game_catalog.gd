class_name GameCatalog
extends Resource
## Root of the game's data. Loaded once by the GameData autoload from data/catalog.tres.

@export var worlds: Array[WorldData] = []
@export var weapons: Array[WeaponData] = []
@export var enemies: Array[EnemyData] = []
