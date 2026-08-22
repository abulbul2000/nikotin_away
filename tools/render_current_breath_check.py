from PIL import Image, ImageDraw, ImageFilter
import math

W = H = 900
img = Image.new('RGBA', (W, H), (8, 18, 31, 255))
p = img.load()
center = (W // 2, H // 2)
outer = 315
accent = (76, 190, 220)
# Approximate the current radial circle decoration from breath_test_page.dart.
for y in range(H):
    for x in range(W):
        dx = x - center[0]
        dy = y - center[1]
        d = math.hypot(dx, dy)
        if d <= outer:
            t = min(1.0, d / outer)
            alpha = int(255 * (0.26 * (1-t) + 0.04*t))
            base = (19, 34, 56)
            rr = int(base[0] * (1-t) + accent[0] * t)
            gg = int(base[1] * (1-t) + accent[1] * t)
            bb = int(base[2] * (1-t) + accent[2] * t)
            p[x, y] = (rr, gg, bb, 255)

d = ImageDraw.Draw(img)
d.ellipse((center[0]-outer, center[1]-outer, center[0]+outer, center[1]+outer), outline=(76, 190, 220, 190), width=5)
# Current code uses Icons.check_rounded, green, diameter * 0.58.
# Draw a large rounded green check without adding a green outer circle.
check = [(center[0]-125, center[1]+5), (center[0]-35, center[1]+100), (center[0]+155, center[1]-125)]
shadow = [(x+7, y+10) for x, y in check]
d.line(shadow, fill=(0, 0, 0, 70), width=38, joint='curve')
d.line(check, fill=(53, 185, 78, 255), width=34, joint='curve')
for x, y in check:
    d.ellipse((x-17, y-17, x+17, y+17), fill=(53, 185, 78, 255))

img.save('/home/ubuntu/nikotin_away/docs/current_breath_success_preview.png')
print('/home/ubuntu/nikotin_away/docs/current_breath_success_preview.png')
