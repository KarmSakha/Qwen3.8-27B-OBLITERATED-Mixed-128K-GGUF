"""Tensor + metadata inventory for the Q8_K_P source. No tokenizer text, no secrets."""
import json, sys
from pathlib import Path
from gguf import GGUFReader

src = Path(sys.argv[1])
out_path = Path(sys.argv[2])
r = GGUFReader(str(src))
meta = {}
for k, f in r.fields.items():
    if k.startswith('tokenizer.ggml.'):
        continue
    try:
        meta[k] = f.contents()
    except Exception:
        meta[k] = str(f.types)
tensors = []
for t in r.tensors:
    tensors.append({
        'name': t.name,
        'shape': [int(x) for x in t.shape],
        'type': str(t.tensor_type),
        'bytes': int(t.n_bytes),
    })
groups = {}
for t in tensors:
    key = t['name'].split('.')[0] if not t['name'].startswith('blk.') else 'blk.*.' + t['name'].split('.', 2)[-1]
    g = groups.setdefault(key, {'count': 0, 'bytes': 0, 'types': set()})
    g['count'] += 1; g['bytes'] += t['bytes']; g['types'].add(t['type'])
out = {
    'file': src.name, 'bytes': src.stat().st_size,
    'metadata': meta,
    'tensor_count': len(tensors),
    'groups': {k: {'count': v['count'], 'bytes': v['bytes'], 'types': sorted(v['types'])} for k, v in sorted(groups.items())},
    'tensors': tensors,
}
out_path.write_text(json.dumps(out, indent=1, default=str))
print('inventory ok:', len(tensors), 'tensors')
