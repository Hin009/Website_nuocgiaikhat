"""Export Docker product images and verify every local database image reference."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[1]
PREFIX = '/api/v1/media/products/'


def docker(*args):
    result = subprocess.run(['docker', 'compose', *args], cwd=ROOT,
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True)
    return result.stdout


def main():
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    backup = ROOT / '.tools' / ('product-images-export-' + stamp)
    backup.mkdir(parents=True)
    exported = backup / 'uploads'
    exported.mkdir()
    docker('cp', 'api:/app/uploads/.', str(exported))
    sql = "SELECT coalesce(json_agg(duong_dan ORDER BY id), '[]') FROM hinh_anh_san_pham"
    references = json.loads(docker(
        'exec', '-T', 'db', 'sh', '-c',
        'exec psql -X -qAt -v ON_ERROR_STOP=1 -U "$POSTGRES_USER" -d "$POSTGRES_DB" -c "$1"',
        '--', sql))
    images = sorted(p for p in exported.iterdir()
                    if p.is_file() and p.suffix.lower() in {'.png', '.jpg', '.jpeg', '.webp'})
    names = {p.name for p in images}
    local = {url[len(PREFIX):] for url in references if url and url.startswith(PREFIX)}
    missing = sorted(local - names)
    if missing:
        raise RuntimeError('Database images missing from Docker export: ' + ', '.join(missing))
    target = ROOT / 'product-images'
    target.mkdir(exist_ok=True)
    manifest = []
    for image in images:
        shutil.copy2(image, target / image.name)
        manifest.append({'file': image.name, 'bytes': image.stat().st_size,
                         'sha256': hashlib.sha256(image.read_bytes()).hexdigest()})
    report = {'exported_at_utc': stamp, 'image_count': len(images),
              'local_database_images': len(local),
              'external_database_images': sum(bool(url) and not url.startswith(PREFIX) for url in references),
              'total_bytes': sum(item['bytes'] for item in manifest), 'files': manifest}
    (ROOT / 'database' / 'product-images-manifest.json').write_text(
        json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps({key: value for key, value in report.items() if key != 'files'}))


if __name__ == '__main__':
    main()
