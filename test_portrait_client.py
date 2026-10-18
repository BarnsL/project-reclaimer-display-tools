"""Small checks for the version-pinned local portrait client builder."""
import importlib.util
from pathlib import Path
import struct
import tempfile
import unittest

MODULE = Path(__file__).with_name('portrait_client.py')
assert MODULE.is_file(), 'Portrait client builder is missing'
spec = importlib.util.spec_from_file_location('portrait_client', MODULE)
mod = importlib.util.module_from_spec(spec)
spec.loader.exec_module(mod)


class PortraitClientTests(unittest.TestCase):
    def test_layout_changes_safe_frame_without_squashing_widgets(self):
        plan = mod.make_edits(1050, 1680)
        payload = next(after for _, _, after in plan if len(after) == mod.CAVE_SIZE)
        self.assertEqual(struct.unpack_from('<IIffffff', payload, mod.PAYLOAD_DELTA),
                         (1280, 720, 55.0, 661.0, 58.0, 4.0,
                          struct.unpack('<f', struct.pack('<f', .97))[0],
                          struct.unpack('<f', struct.pack('<f', .97 * 1280 * 1680 / (720 * 1050)))[0]))

    def test_startup_changes_only_native_branch(self):
        plan = mod.make_edits(1050, 1680)
        offset = mod.file_offset(0x826DED)
        code = next(after for pos, _, after in plan if pos == offset)
        # Decode the conditional destination and selected size independently.
        self.assertEqual(code[:4], bytes.fromhex('31c984db'))  # zero result; test display mode
        self.assertEqual(code[4], 0x74)
        self.assertEqual(0x826DED + 6 + struct.unpack('b', code[5:6])[0], 0x826E70)
        self.assertEqual(code[6:8], bytes.fromhex('48b8'))
        self.assertEqual(struct.unpack_from('<II', code, 8), (1050, 1680))
        self.assertEqual(code[16], 0xE9)
        self.assertEqual(0x826DED + 21 + struct.unpack_from('<i', code, 17)[0], 0x826E67)
        # All existing fixed-resolution choices start here and remain untouched.
        for pos, before, after in plan:
            self.assertEqual(len(before), len(after))
            self.assertFalse(pos < mod.file_offset(0x826E7D) and
                             pos + len(after) > mod.file_offset(0x826E2D))

    def test_rejects_invalid_dimensions(self):
        for width, height in [(1920, 1080), (1051, 1680), (0, 1680), (1050, 9000)]:
            with self.assertRaises(ValueError):
                mod.make_edits(width, height)

    def test_unknown_input_and_existing_output_are_preserved(self):
        with tempfile.TemporaryDirectory(prefix='portrait-client-test-') as directory:
            source = Path(directory, 'source.exe')
            target = Path(directory, 'portrait.exe')
            source.write_bytes(b'MZ synthetic unsupported build')
            with self.assertRaises(ValueError):
                mod.build(source, target, 1050, 1680)
            self.assertFalse(target.exists())
            target.write_bytes(b'existing output')
            with self.assertRaises((ValueError, FileExistsError)):
                mod.build(source, target, 1050, 1680)
            self.assertEqual(target.read_bytes(), b'existing output')
            self.assertEqual(source.read_bytes(), b'MZ synthetic unsupported build')

    def test_edits_do_not_overlap(self):
        plan = sorted(mod.make_edits(1050, 1680))
        for (start, before, _), (next_start, _, _) in zip(plan, plan[1:]):
            self.assertLessEqual(start + len(before), next_start)


if __name__ == '__main__':
    unittest.main()
