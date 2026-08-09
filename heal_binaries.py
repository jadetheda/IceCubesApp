#!/usr/bin/env python3
import os, sys, shutil, time, urllib.request, tarfile, io

BIN_EXTS = {'.png', '.heic', '.caf', '.wav', '.ttf', '.otf'}
BACKUP_DIR = '/tmp/ice_cubes_binary_backup'
REPO_TAR_URL = 'https://github.com/Dimillian/IceCubesApp/archive/refs/heads/main.tar.gz'

def is_corrupt(file_path):
    try:
        if not os.path.exists(file_path) or os.path.getsize(file_path) == 0:
            return True
        with open(file_path, 'rb') as f:
            header = f.read(16)
            if not header:
                return True
            if header.startswith(b'version https://git-lfs') or header.startswith(b'<<<<<<<') or header.startswith(b'======='):
                return True
            ext = os.path.splitext(file_path)[1].lower()
            if ext == '.png' and not header.startswith(b'\x89PNG\r\n\x1a\n'):
                return True
            if ext in ('.wav', '.caf') and not (header.startswith(b'RIFF') or header.startswith(b'caff')):
                return True
            return False
    except Exception:
        return True

def scan_binaries(base_dir):
    all_binaries = []
    corrupt_binaries = []
    for root, dirs, files in os.walk(base_dir):
        if '.git' in root or 'node_modules' in root or 'build' in root or '.build' in root:
            continue
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in BIN_EXTS:
                p = os.path.join(root, f)
                all_binaries.append(p)
                if is_corrupt(p):
                    corrupt_binaries.append(p)
    return all_binaries, corrupt_binaries

def update_backup_cache(base_dir, all_binaries):
    os.makedirs(BACKUP_DIR, exist_ok=True)
    for p in all_binaries:
        rel_p = os.path.relpath(p, base_dir)
        dest_p = os.path.join(BACKUP_DIR, rel_p)
        os.makedirs(os.path.dirname(dest_p), exist_ok=True)
        if not os.path.exists(dest_p) or os.path.getsize(p) != os.path.getsize(dest_p):
            shutil.copy2(p, dest_p)

def restore_from_local_backup(base_dir, corrupt_binaries):
    restored = 0
    for p in corrupt_binaries:
        rel_p = os.path.relpath(p, base_dir)
        src_p = os.path.join(BACKUP_DIR, rel_p)
        if os.path.exists(src_p) and not is_corrupt(src_p):
            os.makedirs(os.path.dirname(p), exist_ok=True)
            shutil.copy2(src_p, p)
            restored += 1
    return restored

def restore_from_remote_tarball(base_dir):
    print("Fetching remote tarball archive from GitHub...")
    req = urllib.request.urlopen(REPO_TAR_URL)
    data = req.read()
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:gz') as tar:
        for member in tar.getmembers():
            ext = os.path.splitext(member.name)[1].lower()
            if ext in BIN_EXTS and member.isfile():
                parts = member.name.split('/')[1:]
                if not parts:
                    continue
                target_rel = os.path.join(base_dir, *parts)
                f = tar.extractfile(member)
                if f:
                    content = f.read()
                    os.makedirs(os.path.dirname(target_rel), exist_ok=True)
                    with open(target_rel, 'wb') as out_f:
                        out_f.write(content)

def main():
    base_dir = os.path.dirname(os.path.abspath(__file__))
    t0 = time.time()
    all_binaries, corrupt_binaries = scan_binaries(base_dir)
    scan_time = time.time() - t0

    if not corrupt_binaries:
        print(f"✅ All {len(all_binaries)} binary files intact! (Checked in {scan_time:.3f}s)")
        update_backup_cache(base_dir, all_binaries)
        sys.exit(0)

    print(f"⚠️ Found {len(corrupt_binaries)} corrupt binary file(s). Healing...")
    
    restored = restore_from_local_backup(base_dir, corrupt_binaries)
    if restored == len(corrupt_binaries):
        print(f"⚡ Restored all {restored} corrupt binaries from local backup cache in {time.time()-t0:.3f}s!")
        sys.exit(0)

    restore_from_remote_tarball(base_dir)
    all_binaries, still_corrupt = scan_binaries(base_dir)
    if not still_corrupt:
        update_backup_cache(base_dir, all_binaries)
        print(f"✨ Restored all binary files from GitHub tarball in {time.time()-t0:.2f}s!")
    else:
        print(f"⚠️ Restored binaries, but {len(still_corrupt)} file(s) remain unhealed.")

if __name__ == '__main__':
    main()
