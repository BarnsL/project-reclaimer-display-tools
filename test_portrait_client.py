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
    def test_portrait_viewport_preserves_widget_proportions(self):
        plan = mod.make_edits(1050, 1680)
        cave = next(after for _, _, after in plan if len(after) == mod.CAVE_SIZE)
        code = cave[84:168]
        for width, height in [(1050, 1680), (1080, 1920), (1080, 1080)]:
            memory = {0xAD314C: 720.0, 0xAD3154: 720.0, 0xAD3164: 661.0}
            regs = [0.0, 0.0, (width / height) / (16 / 9)]
            pc = 0
            # Execute the emitted scalar transform against independent viewport cases.
            while code[pc] != 0xE9:
                op = code[pc:pc + 4]
                if op in (bytes.fromhex('f30f100d'), bytes.fromhex('f30f1105'), bytes.fromhex('f30f5805')):
                    address = 0x2ED53F + pc + 8 + struct.unpack_from('<i', code, pc + 4)[0]
                    if op == bytes.fromhex('f30f100d'):
                        regs[1] = memory[address]
                    elif op == bytes.fromhex('f30f1105'):
                        memory[address] = regs[0]
                    else:
                        regs[0] += memory[address]
                    pc += 8
                elif code[pc:pc + 3] == bytes.fromhex('0f28c1'):
                    regs[0] = regs[1]
                    pc += 3
                elif op == bytes.fromhex('f30f5ec2'):
                    regs[0] /= regs[2]
                    pc += 4
                elif op == bytes.fromhex('f30f5cc1'):
                    regs[0] -= regs[1]
                    pc += 4
                else:
                    self.fail('Unexpected instruction in the HUD transform')
            self.assertEqual(0x2ED53F + pc + 5 + struct.unpack_from('<i', code, pc + 1)[0], 0x2ED592)
            self.assertAlmostEqual(memory[0xAD314C], 1280 * height / width)
            self.assertAlmostEqual(memory[0xAD3154], memory[0xAD314C])
            self.assertAlmostEqual(memory[0xAD3164], memory[0xAD314C] - 59)
            self.assertAlmostEqual(height / memory[0xAD314C], width / 1280)
        self.assertEqual(code[83], 0x41)  # Preserve the first byte of the next original instruction.

    def test_added_code_has_unwind_metadata(self):
        plan = mod.make_edits(1050, 1680)
        entry = next(after for _, before, after in plan if len(before) == 12)
        start, end, unwind = struct.unpack('<III', entry)
        self.assertEqual((start, end, unwind), (mod.CAVE_RVA + 168, mod.CAVE_RVA + 250, 0x2472D64))

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
