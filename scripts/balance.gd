extends RefCounted
## Всички числа за баланса на едно място. Смени ги тук, за да стане играта по-бърза или по-бавна.

# Героят
const PLAYER_SPEED := 5.2
const CAPACITY := 6            # колко цепеници носи в началото
const CAPACITY_BACKPACK := 12  # с раницата
const CHOP_EVERY := 0.45       # секунди между ударите с брадвата
const CHOP_EVERY_SHARP := 0.25 # с острата брадва
const CHOP_RANGE := 1.7
const COIN_RANGE := 1.5
const COIN_PICK_EVERY := 0.03
const PAD_RANGE := 1.0
const PAD_PAY_EVERY := 0.04

# Дърветата
const TREE_LOGS := 4           # цепеници от едно дърво
const TREE_REGROW := 9.0       # секунди, докато израсне ново

# Огънят
const FIRE_RANGE := 2.4        # от толкова близо хвърляш дървата
const FUEL_PER_LOG := 8.0      # секунди горене от една цепеница
const FUEL_START := 30.0
const FUEL_MAX := 80.0
const FUEL_MAX_BIG := 160.0
const FEED_EVERY := 0.09

# Пътниците
const SPAWN_EVERY := 3.5
const SPAWN_EVERY_BIG := 2.2
const WARM_TIME := 5.0         # колко се топли, преди да плати
const PATIENCE := 20.0         # колко чака до угаснал огън, преди да си тръгне
const PAY := 3                 # монети от пътник
const PAY_TENT := 3            # още толкова с палатката
const TRAVELLER_SPEED := 2.8

# Дърварите
const HELPER_SPEED := 3.3
const HELPER_CARRY := 4
const HELPER_CHOP_EVERY := 0.6

# Докато те няма: само с дървар огънят гори, до 4 часа
const OFFLINE_MAX := 4.0 * 3600.0
const OFFLINE_SHARE := 0.15    # каква част от нормалната печалба

# Лагерът
const BOUNDS := Rect2(-11.0, -13.5, 24.0, 21.5)  # x, z, ширина, дълбочина
const SEAT_R := 2.7            # пейките около огъня
const RING_R := 4.4            # пътеката на пътниците около лагера
const SEATS_BASE := [130.0, 180.0, 230.0]  # градуси; 0 = към камерата
const SEATS_BENCH := [90.0, 270.0]
const SEATS_BIG := [50.0, 310.0]
const SPAWN_POS := Vector3(12.0, 0.0, 9.0)
const ENTRY_ANGLE := 40.0
const EXIT_ANGLE := 320.0
const EXIT_POS := Vector3(-12.0, 0.0, 9.0)
const PLAYER_START := Vector3(0.0, 0.0, 3.6)

const TREES := [
	Vector3(-4.6, 0, -6.8), Vector3(-1.6, 0, -8.0), Vector3(1.7, 0, -7.2), Vector3(4.6, 0, -8.4),
	Vector3(-3.1, 0, -10.4), Vector3(0.2, 0, -11.0), Vector3(3.3, 0, -11.3),
]
const TREES_FOREST := [
	Vector3(8.2, 0, -4.6), Vector3(10.6, 0, -3.0), Vector3(9.3, 0, -7.2),
	Vector3(11.8, 0, -6.2), Vector3(7.5, 0, -9.6), Vector3(10.7, 0, -10.2),
]

## Квадратите за строене — появяват се в този ред, по два наведнъж.
const PADS := [
	{"id": "bench", "name": "Още пейки", "icon": "🪵", "cost": 12, "pos": Vector3(-3.7, 0, 3.3)},
	{"id": "backpack", "name": "Раница", "icon": "🎒", "cost": 25, "pos": Vector3(3.7, 0, 3.3)},
	{"id": "helper", "name": "Дървар", "icon": "🪓", "cost": 50, "pos": Vector3(-2.3, 0, -4.6)},
	{"id": "tent", "name": "Палатка", "icon": "⛺", "cost": 80, "pos": Vector3(-6.6, 0, 0.6)},
	{"id": "axe", "name": "Остра брадва", "icon": "🪓", "cost": 110, "pos": Vector3(2.3, 0, -4.6)},
	{"id": "helper2", "name": "Втори дървар", "icon": "🪓", "cost": 160, "pos": Vector3(-2.3, 0, -4.6)},
	{"id": "forest", "name": "Нова гора", "icon": "🌲", "cost": 220, "pos": Vector3(6.8, 0, -1.6)},
	{"id": "bigfire", "name": "Голям огън", "icon": "🔥", "cost": 320, "pos": Vector3(0.0, 0, 4.6)},
]
