"""MRA checks for

Run from the repository root: python -m unittest discover tests
(scripts/run_tests.py runs it as the "mra" step). tests/tb_prom_load.v
simulates the download itself.
"""
import pathlib
import sys
import unittest
import xml.etree.ElementTree as ET
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import make_mra  # noqa: E402


class MraTest(unittest.TestCase):
    def setUp(self):
        self.dumps = make_mra.read_dumps()

    def test_checked_in_mra_matches_script(self):
        self.assertEqual(make_mra.MRA.read_text(encoding='ascii'),
                         make_mra.render(self.dumps))

    def test_parts_follow_layout(self):
        rom = ET.parse(make_mra.MRA).getroot().find('rom')
        self.assertEqual(rom.get('index'), '0')
        self.assertEqual(rom.get('zip'), 'fonz.zip')
        parts = rom.findall('part')
        self.assertEqual([p.get('name') for p in parts],
                         [name for name, _, _ in make_mra.LAYOUT])
        for part in parts:
            crc = zlib.crc32(self.dumps[part.get('name')])
            self.assertEqual(part.get('crc'), f'{crc:08x}')

    def test_download_matches_extracted_hex(self):
        # The download carries the dumps unchanged: same nibbles, same bit
        # order as rom/*.hex, which the simulation reads.
        image = make_mra.assemble(self.dumps)
        self.assertEqual(len(image), 0x600)
        for name, _, offset in make_mra.LAYOUT:
            hex_file = ROOT / 'rom' / (name + '.hex')
            expected = bytes(int(x, 16) for x in hex_file.read_text().split())
            self.assertEqual(image[offset:offset + len(expected)], expected, name)


if __name__ == '__main__':
    unittest.main()
