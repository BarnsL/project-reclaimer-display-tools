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
SUPPORTED_ENGINE_SHA256 = 'b209d8454b12dc77e54ccd2c9924ec8d44b8619d21cf98e36ffaf601e67efb63'
TEXT_VIRTUAL_SIZE = 32749318
CAVE_RVA = 0x1F3C706
CAVE_SIZE = 250
ENGINE_PATCH_RVA = 0x2ED53F
ENGINE_ORIGINAL = bytes.fromhex(
    '410fbfd2410fbfce8bc22bc1660f6ec80f5bc90f28c1f30f59c2f30f5cc8'
    '660f6ec10f5bc0f3410f59c8f30f58c1f3440f2cf0660f6ec20f5bc0664489'
    '35bf5b7e00f30f5cc1f3440f2cd066448915b25b7e0041')


def file_offset(rva):
    return rva - 0xC00  # Pinned .text RVA/raw mapping; never used for another build.


def jump(source, target):
    return b'\xe9' + struct.pack('<i', target - source - 5)


def make_edits(width, height):
    if not (640 <= width < height <= 8192) or width % 2 or height % 2:
        raise ValueError('Use even portrait dimensions from 640 through 8192.')
    if 1280 * height / width > 8192:
        raise ValueError('The requested portrait aspect exceeds the reviewed HUD range.')

    # The engine's existing aspect < 16:9 branch enters this block. Keep the full
    # viewport and compensate its virtual Y coordinates instead of cropping it.
    engine = bytearray()
    def scalar(opcode, target):
        engine.extend(bytes.fromhex(opcode))
        engine.extend(struct.pack('<i', target - (ENGINE_PATCH_RVA + len(engine) + 4)))
    scalar('f30f100d', 0xAD314C)  # xmm1 = original virtual height
    engine.extend(bytes.fromhex('0f28c1f30f5ec2'))  # xmm0 = height / aspect ratio
    scalar('f30f1105', 0xAD314C)
    scalar('f30f1105', 0xAD3154)
    engine.extend(bytes.fromhex('f30f5cc1'))  # virtual-height increase
    scalar('f30f5805', 0xAD3164)  # keep the sensor's original bottom inset
    scalar('f30f1105', 0xAD3164)
    engine.extend(jump(ENGINE_PATCH_RVA + len(engine), 0x2ED592))
    engine.extend(b'\x90' * (83 - len(engine)))
    engine.append(0x41)  # Unchanged first byte of the following instruction.

    # Reuse the client's checked seven-byte patcher before engine startup. It
    # validates original bytes, restores page protection and flushes instructions.
    # Any failure follows the original startup error path, before gameplay.
    stub_rva = CAVE_RVA + 168
    stub = bytearray.fromhex('4889ce4c89c54889d7')  # return pointer, saved option, engine base
    stub.extend(bytes.fromhex('4c8d3d') + struct.pack('<i', CAVE_RVA - (stub_rva + len(stub) + 7)))
    stub.extend(bytes.fromhex('31db'))
    loop = len(stub)
    stub.extend(bytes.fromhex('488d4c2438488d941f') + struct.pack('<I', ENGINE_PATCH_RVA))
    stub.extend(bytes.fromhex('4d8b041f4d8d4c1f54'))
    stub.extend(b'\xe8' + struct.pack('<i', 0x5A77B0 - (stub_rva + len(stub) + 5)))
    stub.extend(bytes.fromhex('31c0483b4424387005'))
    stub.extend(jump(stub_rva + len(stub), 0x59D3E1))
    stub.extend(bytes.fromhex('83c30783fb5472'))
    stub.extend(struct.pack('b', loop - (len(stub) + 1)))
    stub.extend(bytes.fromhex('4989e84889fa41833801'))
    stub.extend(jump(stub_rva + len(stub), 0x59D085))
    cave = ENGINE_ORIGINAL + engine + stub
    if len(ENGINE_ORIGINAL) != 84 or len(engine) != 84 or len(stub) != 82 or len(cave) != CAVE_SIZE:
        raise ValueError('Internal engine patch size mismatch.')

    # Only the native/default fullscreen startup case changes. The windowed case
    # and every explicit in-game resolution preset retain their original branches.
    native_rva = 0x826DED
    native = bytes.fromhex('31c984db74') + struct.pack('b', 0x826E70 - (native_rva + 6))
    native += bytes.fromhex('48b8') + struct.pack('<II', width, height)
    native += jump(native_rva + len(native), 0x826E67)
    native += b'\x90' * (64 - len(native))

    sites = [
        (0x59D07E, '4889ce41833801', jump(0x59D07E, stub_rva) + b'\x90\x90'),
        (native_rva, '84db410f94c031c94108d075768d9080fdffff81fa801b000077684889c248c1ea20448d821fefffff4181f8fff0ffff410f92c008c24408c2f6c201743ceb43', native),
    ]
    edits = [(file_offset(rva), bytes.fromhex(before), after) for rva, before, after in sites]
    edits += [(file_offset(CAVE_RVA), b'\xcc' * CAVE_SIZE, bytes(cave)),
              (0x188, struct.pack('<I', TEXT_VIRTUAL_SIZE),
               struct.pack('<I', TEXT_VIRTUAL_SIZE + CAVE_SIZE)),
              (42759156, bytes(12), struct.pack('<III', stub_rva, CAVE_RVA + CAVE_SIZE, 0x2472D64)),
              (512, struct.pack('<I', 975348), struct.pack('<I', 975360)),
              (284, struct.pack('<I', 975348), struct.pack('<I', 975360))]
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


def build(source, output, width, height, engine=None):
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
    if engine is None:
        raise ValueError('Supply the installed halo3.dll for engine-version verification.')
    engine = Path(engine).absolute()
    no_links(engine)
    if digest(engine) != SUPPORTED_ENGINE_SHA256:
        raise ValueError('Unsupported or modified Halo 3 engine. No client was created.')
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
            'engine_sha256': SUPPORTED_ENGINE_SHA256,
            'viewport': [width, height], 'hud': 'Full viewport with aspect-correct virtual Y coordinates',
            'status': 'Experimental copy built. Live rendering and HUD checks are still required.'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    parser.add_argument('--engine', required=True, type=Path)
    parser.add_argument('--width', type=int, default=1050)
    parser.add_argument('--height', type=int, default=1680)
    args = parser.parse_args()
    try:
        print(json.dumps(build(args.source, args.output, args.width, args.height, args.engine), indent=2))
    except (OSError, ValueError) as error:
        parser.exit(1, str(error) + '\n')
