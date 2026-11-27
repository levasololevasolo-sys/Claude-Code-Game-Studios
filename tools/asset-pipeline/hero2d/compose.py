import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
REPO = os.path.abspath(os.path.join(HERE, '..', '..', '..'))
EV = REPO + '/production/qa/evidence'
FIG = HERE + '/figs'
FB = '/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf'
FS = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf'
FSB = '/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf'

CAP = {
    1: 'Медвежья шкура на плечах',
    2: 'Волчий капюшон, странник',
    3: 'Великан с бревном',
    4: 'Молодой страж с косой',
    5: 'Седой старый богатырь',
    6: 'Вернувшийся из Нави',
    7: 'В погребальных рушниках',
    8: 'Кожа в углях Смородины',
    9: 'Длиннорукий драчун',
    10: 'Коренастый крепыш',
}


def panel(w, h, seed=0):
    rng = np.random.default_rng(seed)
    y = np.linspace(0, 1, h)[:, None]
    x = np.linspace(-1, 1, w)[None, :]
    top = np.array([0.13, 0.17, 0.16]); bot = np.array([0.07, 0.09, 0.08])
    base = top * (1 - y[..., None]) + bot * y[..., None]
    vig = 1 - 0.35 * (x ** 2)[..., None] - 0.2 * ((y - 0.45) ** 2)[..., None]
    glow = 0.06 * np.exp(-((x * 0.9) ** 2 + ((y - 0.55) * 2.2) ** 2))[..., None] * np.array([1.0, 0.85, 0.5])
    n = Image.fromarray((rng.random((h // 24 + 2, w // 24 + 2)) * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    n = (np.asarray(n) / 255.0 - 0.5)[..., None] * 0.03
    img = np.clip(base * vig + glow + n, 0, 1)
    im = Image.fromarray((img * 255).astype(np.uint8)).convert('RGBA')
    # ground line
    d = ImageDraw.Draw(im)
    gy = int(h * 0.86)
    d.ellipse((int(w * 0.05), gy - 10, int(w * 0.95), gy + 26), fill=(10, 14, 12, 255))
    return im.filter(ImageFilter.GaussianBlur(1.2)), gy


def fig(i, t):
    im = Image.open(f'{FIG}/v{i:02d}_t{t}.png')
    return im.crop(im.getbbox())


UNITPX = 90.0


def place(canvas, im, h, cx, ground, fixed=True):
    s = h / (4.7 * UNITPX) if fixed else h / im.height
    im2 = im.resize((max(1, int(im.width * s)), int(h)), Image.LANCZOS)
    canvas.alpha_composite(im2, (int(cx - im2.width / 2), int(ground - im2.height)))
    return im2


def text(d, xy, s, font, fill, anchor='la', stroke=0):
    d.text(xy, s, font=font, fill=fill, anchor=anchor, stroke_width=stroke, stroke_fill=(10, 8, 10))


def sheet():
    W, H = 2560, 1440
    cw, ch = W // 5, H // 2
    out = Image.new('RGBA', (W, H), (12, 14, 13, 255))
    fnum = ImageFont.truetype(FB, 84)
    fcap = ImageFont.truetype(FSB, 27)
    fsm = ImageFont.truetype(FS, 20)
    for k in range(10):
        i = k + 1
        cell, gy = panel(cw - 12, ch - 12, seed=i)
        d = ImageDraw.Draw(cell)
        t1 = fig(i, 1); t5 = fig(i, 5)
        hh = 0.66 * (ch - 12)
        place(cell, t1, hh * min(1.0, 1.0), cw * 0.4, gy + 4)
        place(cell, t5, hh * 0.62, cw * 0.78, gy + 4)
        text(d, (18, 6), str(i), fnum, (255, 201, 74), stroke=3)
        text(d, (cw * 0.4, gy + 30), 'ярус 1', fsm, (190, 180, 160), 'ma')
        text(d, (cw * 0.78, gy + 30), 'ярус 5', fsm, (190, 180, 160), 'ma')
        text(d, ((cw - 12) / 2, ch - 12 - 46), CAP[i], fcap, (237, 230, 242), 'ma', stroke=2)
        d.rectangle((0, 0, cw - 13, ch - 13), outline=(200, 144, 46, 255), width=2)
        out.alpha_composite(cell, ((k % 5) * cw + 6, (k // 5) * ch + 6))
    out.convert('RGB').save(EV + '/hero-variants-sheet.png')


def single(i, name):
    W, H = 1400, 1000
    im, gy = panel(W, H, seed=100 + i)
    d = ImageDraw.Draw(im)
    t1 = fig(i, 1); t5 = fig(i, 5)
    place(im, t1, 700, 380, gy + 4)
    place(im, t5, 560, 860, gy + 4)
    # in-game scale check: 160 px and black silhouette at 48 px
    small = place(im, t1, 160, 1230, gy + 4, fixed=False)
    a = np.asarray(t1)[..., 3]
    sil = Image.fromarray(np.dstack([np.zeros_like(a)] * 3 + [a]).astype(np.uint8), 'RGBA')
    sil = sil.resize((max(1, int(sil.width * 48 / sil.height)), 48), Image.LANCZOS)
    plate = Image.new('RGBA', (90, 70), (200, 196, 184, 255))
    plate.alpha_composite(sil, ((90 - sil.width) // 2, 11))
    im.alpha_composite(plate, (1185, 140))
    f1 = ImageFont.truetype(FB, 96); f2 = ImageFont.truetype(FSB, 40); f3 = ImageFont.truetype(FS, 22)
    text(d, (30, 10), str(i), f1, (255, 201, 74), stroke=3)
    text(d, (150, 40), name, f2, (237, 230, 242), stroke=2)
    text(d, (150, 92), CAP[i], f3, (200, 190, 170))
    text(d, (380, gy + 32), 'ярус 1 «Павший»', f3, (200, 190, 170), 'ma')
    text(d, (860, gy + 32), 'ярус 5 «Богатырь»', f3, (200, 190, 170), 'ma')
    text(d, (1230, gy + 32), '160 px', f3, (200, 190, 170), 'ma')
    text(d, (1230, 216), 'силуэт 48 px', f3, (200, 190, 170), 'ma')
    im.convert('RGB').save(f'{EV}/hero-variant-{i:02d}.png')


def onbg(ids):
    sw = REPO + '/assets/art/sprites/swamp/'
    W, H = 1920, 1080
    out = Image.new('RGBA', (W, H), (0, 0, 0, 255))
    for n, ox in (('bg_far', 200), ('bg_mid', 500), ('bg_near', 900)):
        L = Image.open(sw + n + '.png').convert('RGBA')
        out.alpha_composite(L.crop((ox, 0, ox + W, H)))
    # simple ground strip like the room floor
    g = Image.new('RGBA', (W, 160), (20, 30, 22, 255))
    gd = ImageDraw.Draw(g)
    gd.rectangle((0, 0, W, 10), fill=(46, 62, 40, 255))
    out.alpha_composite(g, (0, 930))
    lab = ImageFont.truetype(FB, 40)
    d = ImageDraw.Draw(out)
    xs = np.linspace(330, 1600, len(ids))
    for x, i in zip(xs, ids):
        # warm light pool of the amulet
        glow = Image.new('RGBA', (W, H), (255, 190, 90, 0))
        gdr = ImageDraw.Draw(glow)
        gdr.ellipse((x - 170, 930 - 260, x + 170, 930 + 40), fill=(255, 190, 90, 38))
        out.alpha_composite(glow.filter(ImageFilter.GaussianBlur(60)))
        place(out, fig(i, 1), 160, x, 934, fixed=False)
        text(d, (x, 960), str(i), lab, (255, 201, 74), 'ma', stroke=3)
    out.convert('RGB').save(EV + '/hero-variants-onbg.png')


if __name__ == '__main__':
    from variants import V
    sheet()
    for i in V:
        single(i, V[i]['name'])
    onbg([int(x) for x in sys.argv[1:]] or [1, 4, 5, 8])
