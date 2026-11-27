from hero import P, hexc, INK
import numpy as np

V = {
    1: P(dict(name='Медвежья шкура', sw=1.12, armk=1.1, handk=1.1, extras=('bear',), weapon='axe', seed=11)),
    2: P(dict(name='Волчий капюшон', sw=0.92, armk=0.92, T=1.5, Lg=1.82, hr=0.42, extras=('wolf',), beard_style='short',
              hair=hexc('6A4A30'), beard=hexc('6A4A30'), weapon='spear', seed=12)),
    3: P(dict(name='Великан-пахарь', sw=1.38, armk=1.3, handk=1.45, hr=0.42, belly=1.35, T=1.55, Lg=1.62,
              stick='log', weapon='mace', hair_style='cropped', beard_style='full', hair=hexc('A87A48'), beard=hexc('A87A48'), seed=13)),
    4: P(dict(name='Молодой страж с косой', sw=0.98, armk=0.95, hr=0.43, extras=('braid', 'scar'), hair_style='braid',
              beard_style='short', hair=hexc('B07C48'), beard=hexc('B07C48'), weapon='sword', seed=14)),
    5: P(dict(name='Седой богатырь', sw=1.1, armk=1.05, extras=('bushy',), hair_style='bald', beard_style='long',
              hair=hexc('C8C4BC'), beard=hexc('D8D4CC'), brow=hexc('9A968E'), skin=hexc('D89A78'), weapon='hammer', seed=15)),
    6: P(dict(name='Вернувшийся из Нави', sw=1.0, skin=hexc('C4A69A'), hair=hexc('9A9088'), beard=hexc('8E847C'),
              eye_glow=hexc('CFE0FF'), extras=('ghost',), weapon='sword', seed=16)),
    7: P(dict(name='Погребальные рушники', sw=1.02, extras=('ribbons',), pants=hexc('BFB090'), weapon='sword', seed=17)),
    8: P(dict(name='Угольная кожа', sw=1.08, skin=hexc('9A5A44'), hair=hexc('3A2A24'), beard=hexc('3A2A24'),
              extras=('embers',), eye_glow=hexc('FFB040'), steel=hexc('6A6670'), weapon='axe', seed=18)),
    9: P(dict(name='Длиннорукий драчун', sw=0.95, armk=1.0, handk=1.5, armlen=1.6, T=1.6, Lg=1.62, hr=0.41,
              weapon='flail', beard_style='short', seed=19)),
    10: P(dict(name='Коренастый крепыш', sw=1.2, armk=1.15, handk=1.15, hr=0.5, T=1.3, Lg=1.3, legk=1.15, belly=1.15,
               extras=('shield', 'braid_beard'), beard_style='long', weapon='sword', seed=20)),
}
