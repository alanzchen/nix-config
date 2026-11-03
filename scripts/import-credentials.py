#!/usr/bin/env python3
"""Review first; import missing SSH keys in one terminal authorization session."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]


def decode_objects(text):
    """Accept an array or streamed JSON objects from op; never print raw output."""
    objects = []
    decoder = json.JSONDecoder()
    while text.strip():
        obj, end = decoder.raw_decode(text.lstrip())
        text = text.lstrip()[end:]
        objects.extend(obj if isinstance(obj, list) else [obj])
    return objects


def prepare_items(plan, existing_titles):
    items = []
    for entry in plan['sshKeys']:
        if entry['title'] in existing_titles:
            continue
        path = Path(entry['path']).expanduser()
        # Validate key integrity and the public side before any vault mutation.
        result = subprocess.run(['/usr/bin/ssh-keygen', '-y', '-P', '', '-f', str(path)], capture_output=True, text=True)
        if result.returncode:
            raise ValueError(f"{entry['title']}: missing, invalid, or passphrase-protected key; no import performed")
        public = path.with_suffix(path.suffix + '.pub').read_text().split()[:2]
        if result.stdout.split()[:2] != public:
            raise ValueError(f"{entry['title']}: private/public key mismatch; no import performed")
        private = path.read_text()
        items.append({
            'title': entry['title'], 'category': 'SSH_KEY', 'tags': [plan['tag']],
            'fields': [{'id': 'private_key', 'type': 'SSHKEY', 'label': 'private key', 'value': private}],
        })
    return items


def update_reference_map(root, plan, receipts):
    """Save identifiers, never values; reuse the already-returned create response."""
    by_title = {item['title']: item.get('item') or item.get('id') for item in receipts}
    path = root/'config/migration/credentials.json'
    manifest = json.loads(path.read_text())
    additional = manifest.setdefault('additionalSshPublicKeys', {})
    for entry in plan['sshKeys']:
        item = by_title.get(entry['title'])
        if item:
            additional[entry['name']] = f"op://{plan['vault']}/{item}/public_key"
    path.write_text(json.dumps(manifest, indent=2)+'\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--apply', action='store_true', help='Import the reviewed missing keys into 1Password')
    args = parser.parse_args()
    plan = json.loads((ROOT/'config/migration/credential-import-plan.json').read_text())
    for entry in plan['sshKeys']:
        exists = Path(entry['path']).expanduser().is_file()
        print(f"{'Ready' if exists else 'Missing'}: {entry['title']} — {entry['purpose']}")
    print('Existing items will not be edited or deleted; original local keys remain in place.')
    if not args.apply:
        print('Preview only: no 1Password access and no private-key reads.')
        return
    if not sys.stdin.isatty():
        raise ValueError('Run --apply from one interactive terminal so authorization can be reused')
    op = shutil.which('op')
    if not op:
        raise ValueError('1Password CLI is required')
    # One metadata lookup makes retries avoid creating duplicates after partial success.
    found = subprocess.run([op,'item','list','--vault',plan['vault'],'--tags',plan['tag'],'--format=json'], capture_output=True,text=True,timeout=120)
    if found.returncode:
        raise ValueError('1Password authorization failed; no import performed')
    existing = json.loads(found.stdout)
    titles = {item['title'] for item in existing}
    items = prepare_items(plan, titles)
    if not items:
        update_reference_map(ROOT, plan, existing)
        print('All planned items already exist under the migration tag; no writes needed.')
        return
    print(f'Importing {len(items)} missing SSH key item(s) in one batch.')
    # Secret material travels through stdin only; stdout/stderr are never displayed.
    result = subprocess.run([op,'item','create','-','--vault',plan['vault'],'--format=json'], input=json.dumps(items),capture_output=True,text=True,timeout=120)
    try:
        created = decode_objects(result.stdout)
    except (ValueError, TypeError):
        created = []
    receipt = [{'title':x.get('title'),'item':x.get('id'),'vault':plan['vault']} for x in created if isinstance(x,dict) and x.get('id')]
    state = Path.home()/'.local/state/mac-bootstrap'
    state.mkdir(parents=True,exist_ok=True,mode=0o700)
    path = state/'credential-import-receipt.json'
    path.write_text(json.dumps(receipt,indent=2)+'\n')
    path.chmod(0o600)
    if result.returncode or len(receipt) != len(items):
        raise ValueError('Import was incomplete or its result is uncertain. A retry checks migration-tagged items first; no raw response was printed.')
    update_reference_map(ROOT, plan, existing + receipt)
    print(f'Created {len(receipt)} item(s). Saved identifiers only to the local migration receipt.')
    print('Updated the local public-key reference map. Commit and push that metadata before using the new Mac installer.')


if __name__ == '__main__':
    try:
        main()
    except (ValueError, OSError, subprocess.SubprocessError) as exc:
        # Do not include subprocess output or JSON bodies in errors.
        if isinstance(exc, subprocess.SubprocessError):
            sys.exit('1Password operation timed out or failed. Retry will check existing tagged items first.')
        sys.exit(str(exc))
