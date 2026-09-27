extends RefCounted
## Как се изписват числата и времето на екрана.

const UNITS := [[1e18, "квинт."], [1e15, "квадр."], [1e12, "трлн."], [1e9, "млрд."], [1e6, "млн."], [1e3, "хил."]]


## 950 → „950“, 12 345 → „12,3 хил.“
static func num(x: float) -> String:
	if x < 1000.0:
		return str(int(x))
	for u in UNITS:
		var unit: float = u[0]
		if x >= unit:
			var v := x / unit
			var dec := 2 if v < 10.0 else (1 if v < 100.0 else 0)
			return _comma(v, dec) + " " + str(u[1])
	return str(int(x))


## За скорости: малките числа са с една цифра след запетаята — „0,3“.
static func rate(x: float) -> String:
	if x < 10.0:
		return _comma(x, 1)
	return num(x)


static func duration(sec: float) -> String:
	var h := floori(sec / 3600.0)
	var m := floori(fmod(sec, 3600.0) / 60.0)
	if h > 0:
		return "%d ч %d мин" % [h, m]
	if m > 0:
		return "%d мин" % m
	return "%d сек" % floori(sec)


static func _comma(v: float, dec: int) -> String:
	var s := ("%." + str(dec) + "f") % v
	if "." in s:
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")
