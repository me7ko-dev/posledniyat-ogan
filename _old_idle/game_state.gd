extends RefCounted
## Икономиката на „Последният огън“: дърва, оцелели, подобрения, запис и прогрес,
## докато играчът го няма. Всички числа за баланса са най-отгоре.

enum Item { RECRUIT, FIRE, AXE, GLOVES }

const SAVE_VERSION := 1
const OFFLINE_CAP := 8.0 * 3600.0  # докато те няма, лагерът работи най-много 8 часа

const SURVIVOR_RATE := 0.5   # дърва/сек от един оцелял без бонуси
const RECRUIT_BASE := 15.0
const RECRUIT_GROWTH := 1.28
const FIRE_BASE := 80.0
const FIRE_GROWTH := 2.5
const FIRE_BONUS := 0.15     # +15% сечене за всяко ниво на огъня над първото
const SEATS_PER_FIRE := 2    # места за оцелели на ниво огън
const BURN_BASE := 0.3       # дърва/сек, които гори огън ниво 1
const BURN_EXP := 1.5
const AXE_BASE := 40.0
const AXE_GROWTH := 2.0
const AXE_BONUS := 0.4       # +40% сечене на ниво
const GLOVES_BASE := 15.0
const GLOVES_GROWTH := 1.9
const GLOVES_SHARE := 0.05   # всеки удар дава и 5% от сеченето/сек за всяко ниво

const NAMES := [
	"Иван", "Мария", "Георги", "Елена", "Петър", "Даниела", "Стоян", "Радка",
	"Тодор", "Веска", "Христо", "Гергана", "Никола", "Цвета", "Димитър", "Милена",
	"Асен", "Калина", "Васил", "Надя", "Любомир", "Росица", "Атанас", "Велина",
	"Борислав", "Яна", "Кирил", "Десислава", "Милко", "Златка", "Ангел", "Теменуга",
]

var wood := 5.0
var names: Array[String] = []  # оцелелите в лагера
var fire_level := 1
var axe_level := 0
var gloves_level := 0
var last_seen := 0.0  # кога е записана играта (секунди, Unix време)


func _init() -> void:
	names.append(_new_name())
	last_seen = now()


static func now() -> float:
	return Time.get_unix_time_from_system()


func survivor_count() -> int:
	return names.size()


func seats() -> int:
	return 1 + SEATS_PER_FIRE * fire_level


func has_seat() -> bool:
	return survivor_count() < seats()


## Колко дърва в секунда носи един оцелял.
func rate_per_survivor() -> float:
	return SURVIVOR_RATE * (1.0 + AXE_BONUS * axe_level) * (1.0 + FIRE_BONUS * (fire_level - 1))


func gather_rate() -> float:
	return rate_per_survivor() * survivor_count()


func burn_rate() -> float:
	return BURN_BASE * pow(fire_level, BURN_EXP)


func net_rate() -> float:
	return gather_rate() - burn_rate()


## Огънят гасне: дървата свършиха и хората не смогват да го хранят.
func is_cold() -> bool:
	return wood <= 0.0 and net_rate() < 0.0


func tap_power() -> float:
	return (1.0 + gloves_level) + gather_rate() * GLOVES_SHARE * gloves_level


func tick(delta: float) -> void:
	wood = maxf(0.0, wood + net_rate() * delta)


func tap() -> float:
	var got := tap_power()
	wood += got
	return got


func cost(item: int) -> float:
	match item:
		Item.RECRUIT:
			return RECRUIT_BASE * pow(RECRUIT_GROWTH, survivor_count() - 1)
		Item.FIRE:
			return FIRE_BASE * pow(FIRE_GROWTH, fire_level - 1)
		Item.AXE:
			return AXE_BASE * pow(AXE_GROWTH, axe_level)
		Item.GLOVES:
			return GLOVES_BASE * pow(GLOVES_GROWTH, gloves_level)
	return INF


func can_buy(item: int) -> bool:
	if item == Item.RECRUIT and not has_seat():
		return false
	return wood >= cost(item)


func buy(item: int) -> bool:
	if not can_buy(item):
		return false
	wood -= cost(item)
	_apply(item)
	return true


## Копие на лагера след покупката (без цената) — за „сега → след“ в менюто.
func preview(item: int) -> RefCounted:
	var copy: RefCounted = get_script().new()
	copy.from_dict(to_dict())
	copy._apply(item)
	return copy


func _apply(item: int) -> void:
	match item:
		Item.RECRUIT:
			names.append(_new_name())
		Item.FIRE:
			fire_level += 1
		Item.AXE:
			axe_level += 1
		Item.GLOVES:
			gloves_level += 1


func _new_name() -> String:
	var free: Array[String] = []
	for n: String in NAMES:
		if not n in names:
			free.append(n)
	if free.is_empty():
		return "%s %d" % [NAMES[randi() % NAMES.size()], names.size() + 1]
	return free[randi() % free.size()]


# --- Докато те няма ---

func seconds_since_seen() -> float:
	return maxf(0.0, now() - last_seen)


## Прогрес, докато играчът го няма (най-много OFFLINE_CAP). Връща промяната в дървата.
func apply_offline(seconds: float) -> float:
	var before := wood
	tick(clampf(seconds, 0.0, OFFLINE_CAP))
	return wood - before


# --- Запис ---

func to_dict() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"wood": wood,
		"names": names.duplicate(),
		"fire_level": fire_level,
		"axe_level": axe_level,
		"gloves_level": gloves_level,
		"last_seen": last_seen,
	}


func from_dict(d: Dictionary) -> void:
	wood = float(d.get("wood", wood))
	names.assign(d.get("names", names))
	fire_level = int(d.get("fire_level", fire_level))
	axe_level = int(d.get("axe_level", axe_level))
	gloves_level = int(d.get("gloves_level", gloves_level))
	last_seen = float(d.get("last_seen", last_seen))


func save(path: String) -> void:
	last_seen = now()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


## Зарежда записа. Връща false, ако няма запис или е повреден (тогава играта е нова).
func load_from(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("Повреден запис: " + path)
		return false
	from_dict(data)
	return true
