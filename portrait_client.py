"""Build a separate, experimental portrait copy of Reclaimer 0.9.18.

No process memory, settings, stock maps or input executable are modified.
Only the exact reviewed unsigned Windows x64 client is accepted.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import struct
import tempfile

SUPPORTED_SHA256 = 'a8d3a37ad27e31abc09d009a94210470976ecefb34908a9fb8e1a245f4924910'
SUPPORTED_SIZE = 43051520
TEXT_VIRTUAL_SIZE = 32749318
CAVE_RVA = 0x1F3C706
CAVE_SIZE = 250
PAYLOAD_DELTA = 10  # Align the two read-only vectors to 16 bytes.


def file_offset(rva):
    return rva - 0xC00  # Pinned .text RVA/raw mapping; never used for another build.


def jump(source, target):
    return b'\xe9' + struct.pack('<i', target - source - 5)


def make_edits(width, height):
    if not (640 <= width < height <= 8192) or width % 2 or height % 2:
        raise ValueError('Use even portrait dimensions from 640 through 8192.')
    aspect_height = 1280 * height / width
    if aspect_height > 8192:
        raise ValueError('The requested portrait aspect exceeds the reviewed HUD range.')

    payload_rva = CAVE_RVA + PAYLOAD_DELTA
    stock_rva = payload_rva + 32
    guard_rva = stock_rva + 16
    cave = bytearray(b'\xcc' * CAVE_SIZE)
    struct.pack_into('<IIffffff', cave, PAYLOAD_DELTA,
                     1280, 720, 55, 661, 58, 4, .97, .97 * aspect_height / 720)
    struct.pack_into('<ffff', cave, PAYLOAD_DELTA + 32, 55, 661, 58, 4)

    # Check the original sensor position/radii in the already-read CHGD record.
    # The existing code separately checks fullscreen flags, canvas and safe frame.
    guard = bytes.fromhex('0f104578')  # movups xmm0,[rbp+78h]
    guard += bytes.fromhex('660f7605') + struct.pack('<i', stock_rva - (guard_rva + 12))
    guard += bytes.fromhex('660fd7c03dffff0000')  # all four fields must match
    guard += bytes.fromhex('0f85') + struct.pack('<i', 0xE7AC4 - (guard_rva + 27))
    guard += bytes.fromhex('488b8588000000')  # displaced safe-frame load
    guard += jump(guard_rva + len(guard), 0xE7BCD)
    guard_offset = PAYLOAD_DELTA + 48
    cave[guard_offset:guard_offset + len(guard)] = guard

    # Replace the existing safe-frame payload with the validated 32-byte layout.
    copy_rva = 0xE7C11
    copy = bytes.fromhex('0f1005') + struct.pack('<i', payload_rva - (copy_rva + 7))
    copy += bytes.fromhex('0f1106')
    copy += bytes.fromhex('0f1005') + struct.pack('<i', payload_rva + 16 - (copy_rva + 17))
    copy += bytes.fromhex('0f1146104889b59801000090')

    # Only the native/default fullscreen startup case changes. The windowed case
    # and every explicit in-game resolution preset retain their original branches.
    native_rva = 0x826DED
    native = bytes.fromhex('31c984db74') + struct.pack('b', 0x826E70 - (native_rva + 6))
    native += bytes.fromhex('48b8') + struct.pack('<II', width, height)
    native += jump(native_rva + len(native), 0x826E67)
    native += b'\x90' * (64 - len(native))

    sites = [
        (0xE7BC6, '488b8588000000', jump(0xE7BC6, guard_rva) + b'\x90\x90'),
        (0xE7BF9, 'ba08000000', bytes.fromhex('ba20000000')),
        (0xE7C11, '48b8ec51783fec51783f488906483985880000004889b5980100007455', copy),
        (0xE7C4B, '41b908000000', bytes.fromhex('41b920000000')),
        (0xE7C54, '498d5528', bytes.fromhex('498d5510')),
        (0xE7C69, '4883bda000000008', bytes.fromhex('4883bda000000020')),
        (native_rva, '84db410f94c031c94108d075768d9080fdffff81fa801b000077684889c248c1ea20448d821fefffff4181f8fff0ffff410f92c008c24408c2f6c201743ceb43', native),
    ]
    edits = [(file_offset(rva), bytes.fromhex(before), after) for rva, before, after in sites]
    edits += [(file_offset(CAVE_RVA), b'\xcc' * CAVE_SIZE, bytes(cave)),
              (0x188, struct.pack('<I', TEXT_VIRTUAL_SIZE),
               struct.pack('<I', TEXT_VIRTUAL_SIZE + guard_offset + len(guard)))]
    if any(len(before) != len(after) for _, before, after in edits):
        raise ValueError('Internal patch length mismatch.')
    return edits


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def no_links(path):
    for part in (path, *path.parents):
        if part.is_symlink() or (part.exists() and
                getattr(part.stat(), 'st_file_attributes', 0) & stat.FILE_ATTRIBUTE_REPARSE_POINT):
            raise ValueError('Linked or redirected paths are not supported.')


def build(source, output, width, height):
    source, output = Path(source).absolute(), Path(output).absolute()
    no_links(source)
    no_links(output)
    if output.exists():
        raise FileExistsError('Output exists. The original and existing copies are never replaced.')
    if not output.parent.is_dir():
        raise ValueError('Create a separate output directory first.')
    edits = make_edits(width, height)
    if source.stat().st_size != SUPPORTED_SIZE or digest(source) != SUPPORTED_SHA256:
        raise ValueError('Unsupported or modified client. Expected the reviewed Reclaimer 0.9.18 build.')
    with source.open('rb') as stream:
        for offset, before, _ in edits:
            stream.seek(offset)
            if stream.read(len(before)) != before:
                raise ValueError('Original instruction or padding verification failed.')

    descriptor, temporary_name = tempfile.mkstemp(prefix='portrait-client-', suffix='.tmp', dir=output.parent)
    os.close(descriptor)
    temporary = Path(temporary_name)
    try:
        shutil.copyfile(source, temporary)
        if digest(temporary) != SUPPORTED_SHA256:
            raise ValueError('The source changed during copying. Nothing was published.')
        with temporary.open('r+b') as stream:
            for offset, _, after in edits:
                stream.seek(offset)
                stream.write(after)
            stream.flush()
            os.fsync(stream.fileno())
        result_hash = digest(temporary)
        no_links(output)
        # Linking an owned temporary file publishes without replacing any file.
        os.link(temporary, output)
        if digest(output) != result_hash:
            raise ValueError('Output verification failed. Preserve this copy for inspection.')
    finally:
        temporary.unlink(missing_ok=True)
    return {'source_sha256': SUPPORTED_SHA256, 'output_sha256': result_hash,
            'viewport': [width, height], 'virtual_hud': [1280, 720],
            'safe_frame_vertical': .97 * 1280 * height / (720 * width),
            'status': 'Experimental copy built. Live rendering and HUD checks are still required.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--width', type=int, default=1050)
    parser.add_argument('--height', type=int, default=1680)
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.source, args.output, args.width, args.height), indent=2))
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + '\n')
