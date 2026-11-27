import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from hero import render
from variants import V
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'figs')
os.makedirs(out, exist_ok=True)
ids = [int(x) for x in sys.argv[1:]] or list(V)
for i in ids:
    for t in (1, 5):
        render(V[i], t).save(f'{out}/v{i:02d}_t{t}.png')
    print(i, flush=True)
