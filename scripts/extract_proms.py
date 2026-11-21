"""Extract the supplied PROMs without changing address order or bit order."""
import hashlib
import pathlib
import zipfile

ROOT = pathlib.Path(__file__).resolve().parents[1]
PROMS = {
    'ic86.86': (512, '88304451ffbd7231d397ada632c7bf6f8cbe7598'),
    'ic87.87': (512, '2f112197d7caafb4cb7e2658ea8b298e15aba6ac'),
    'pr-09.49': (256, 'a03eb4aa726a2e2c872f40dfd1628b00d4edfa33'),
    'pr-08.50': (256, 'fdfa310f54b88610c1f59345f5fc72b3b90641ad'),
}

def main():
    target = ROOT / 'rom'
    target.mkdir(exist_ok=True)
    with zipfile.ZipFile(ROOT / 'fonz.zip') as archive:
        for name, (size, digest) in PROMS.items():
            data = archive.read(name)
            if len(data) != size or hashlib.sha1(data).hexdigest() != digest:
                raise ValueError(f'{name}: unexpected ROM dump')
            if any(byte & 0xf0 for byte in data):
                raise ValueError(f'{name}: not a four-bit PROM dump')
            (target / (name + '.hex')).write_text(
                ''.join(f'{byte:x}\n' for byte in data), encoding='ascii')
            print(f'{name}: {size} addresses, four bits each')

if __name__ == '__main__':
    main()
