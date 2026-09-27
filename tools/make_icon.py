"""Рисува иконата на играта: огън в снежна нощ. Пуска се с `python tools/make_icon.py`.
Прави icon.png (512x512, за Godot/Android) и icon.ico (за иконата на работния плот)."""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024  # рисуваме двойно по-голямо и смаляваме — гладки ръбове
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))

# нощно небе: преливане отгоре надолу
sky = Image.new("RGBA", (S, S))
top, bottom = (10, 14, 38), (46, 38, 78)
px = sky.load()
for y in range(S):
    t = y / (S - 1)
    c = tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,)
    for x in range(S):
        px[x, y] = c
d = ImageDraw.Draw(sky)
# звезди и луна
for (x, y, r) in [(170, 150, 6), (320, 90, 4), (560, 170, 5), (250, 300, 3), (700, 110, 4), (120, 420, 4), (880, 380, 3), (470, 60, 3)]:
    d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 255, 255, 230))
d.ellipse((760, 150, 880, 270), fill=(236, 239, 247, 255))
d.ellipse((790, 185, 815, 210), fill=(214, 218, 230, 255))
# борове на хоризонта
for (x, h) in [(60, 260), (170, 200), (880, 240), (980, 200), (300, 150), (740, 160)]:
    for k in range(3):
        b = 700 - k * h * 0.26
        w = h * 0.3 * (1 - k * 0.22)
        d.polygon([(x - w, b), (x + w, b), (x, b - h * 0.45)], fill=(8, 13, 30, 255))
# снежна поляна
d.ellipse((-300, 640, S + 300, 1500), fill=(78, 90, 124, 255))

# топла светлина около огъня
glow = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(glow)
for r, a in [(420, 40), (320, 60), (220, 90), (140, 120)]:
    g.ellipse((512 - r, 700 - r * 0.8, 512 + r, 700 + r * 0.8), fill=(255, 130, 40, a))
glow = glow.filter(ImageFilter.GaussianBlur(60))
sky = Image.alpha_composite(sky, glow)
d = ImageDraw.Draw(sky)

# камъни и цепеници
for k in range(10):
    a = math.tau * k / 10
    x, y = 512 + math.cos(a) * 190, 790 + math.sin(a) * 55
    d.ellipse((x - 34, y - 24, x + 34, y + 24), fill=(70, 72, 84, 255) if math.sin(a) > 0 else (96, 98, 110, 255))

def log(angle):
    L, W = 230, 30
    ca, sa = math.cos(angle), math.sin(angle)
    pts = [(-L, -W), (L, -W), (L, W), (-L, W)]
    d.polygon([(512 + x * ca - y * sa, 780 + x * sa + y * ca) for x, y in pts], fill=(98, 58, 30, 255))
    for sx in (-L, L):
        cx, cy = 512 + sx * ca, 780 + sx * sa
        d.ellipse((cx - 30, cy - 30, cx + 30, cy + 30), fill=(150, 104, 62, 255))
        d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(120, 80, 45, 255))
log(0.35)
log(-0.35)

def flame(cx, base, w, h, lean, color):
    """Капка с връх нагоре, леко наклонена."""
    pts = []
    for i in range(80):
        t = math.tau * i / 80
        x = math.sin(t) * abs(math.sin(t / 2)) ** 1.6
        y = math.cos(t)  # 1 = връх, -1 = дъно
        top = (y + 1) / 2
        pts.append((cx + x * w + lean * top ** 2, base - (y + 1) / 2 * h))
    d.polygon(pts, fill=color)

flame(512, 790, 200, 560, -40, (214, 52, 24, 255))
flame(470, 790, 120, 380, -60, (232, 84, 30, 255))
flame(570, 790, 120, 420, 50, (232, 84, 30, 255))
flame(512, 790, 150, 430, 20, (255, 140, 36, 255))
flame(512, 790, 100, 300, -15, (255, 204, 70, 255))
flame(512, 790, 50, 170, 5, (255, 244, 200, 255))
for (x, y, r) in [(420, 250, 9), (610, 200, 7), (560, 300, 6), (380, 360, 5), (660, 330, 5)]:
    d.ellipse((x - r, y - r, x + r, y + r), fill=(255, 190, 90, 255))

# заоблен квадрат
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).rounded_rectangle((0, 0, S - 1, S - 1), radius=200, fill=255)
img.paste(sky, (0, 0), mask)

png = img.resize((512, 512), Image.LANCZOS)
png.save("icon.png")
png.save("icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
print("ok")
