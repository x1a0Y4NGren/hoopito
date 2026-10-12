"""Authentic synthetic v1 fixture checks; no Android device or build is used."""

import hashlib
from contextlib import closing
import json
import re
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
TOOL = ROOT / 'tool/release/prepare_v1_upgrade_fixture.py'


class V1UpgradeFixtureTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory(prefix='hoopito-v1-fixture-')
        cls.output = Path(cls.temporary.name) / 'fixture'
        generated = subprocess.run(
            [sys.executable, str(TOOL), '--output', str(cls.output)],
            cwd=ROOT, capture_output=True, text=True,
        )
        if generated.returncode:
            raise AssertionError(generated.stdout + generated.stderr)
        cls.baseline = json.loads((cls.output / 'baseline.json').read_text())
        cls.database = sqlite3.connect(cls.output / 'hooptrace.sqlite')
        cls.database.row_factory = sqlite3.Row

    @classmethod
    def tearDownClass(cls):
        cls.database.close()
        cls.temporary.cleanup()

    def test_exact_v1_schema_and_valid_file(self):
        self.assertEqual(self.database.execute('PRAGMA user_version').fetchone()[0], 2)
        self.assertEqual(self.database.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
        self.assertEqual(self.database.execute('PRAGMA foreign_key_check').fetchall(), [])
        schema = json.loads(subprocess.check_output(
            ['git', 'show', 'v1.0.0:drift_schemas/drift_schema_v2.json'], cwd=ROOT,
        ))
        self.assertEqual(set(self.baseline['tables']), {
            entity['data']['name'] for entity in schema['entities']
        })
        def normalized(sql):
            return re.sub(r'\s+', ' ', sql.replace('IF NOT EXISTS ', '')).strip().rstrip(';')
        for entity in schema['fixed_sql']:
            actual = self.database.execute(
                'SELECT sql FROM sqlite_master WHERE name=?', (entity['name'],),
            ).fetchone()[0]
            self.assertEqual(normalized(actual), normalized(entity['sql'][0]['sql']))
        self.assertEqual(self.baseline['source_commit'],
                         'd8d2937a2d9543c1f0125a1d2d6c4de59f36046e')
        self.assertEqual(self.baseline['database_sha256'], hashlib.sha256(
            (self.output / 'hooptrace.sqlite').read_bytes()).hexdigest())

    def test_history_coverage_snapshots_and_active_scores(self):
        rows = list(self.database.execute('SELECT * FROM matches ORDER BY rowid'))
        self.assertEqual([(r['id'], r['lifecycle'], r['tracking_coverage']) for r in rows], [
            ('upgrade-history-scores', 'finished', 'scoresOnly'),
            ('upgrade-history-locations', 'finished', 'locations'),
            ('upgrade-active', 'active', 'full'),
        ])
        profile = self.database.execute('SELECT nickname FROM players').fetchone()[0]
        snapshot = self.database.execute(
            "SELECT name_snapshot FROM match_participants WHERE id='upgrade-history-scores:red'"
        ).fetchone()[0]
        self.assertEqual(profile, 'Synthetic renamed profile')
        self.assertEqual(snapshot, 'Synthetic original red')
        historical_rule = json.loads(rows[0]['rule_template_json'])
        current_rule = self.database.execute('SELECT name FROM rule_templates').fetchone()[0]
        self.assertEqual(historical_rule['name'], 'Synthetic original rules')
        self.assertEqual(current_rule, 'Synthetic edited template')
        self.assertEqual(self.baseline['expected']['active_score'], {'red': 2, 'blue': 3})
        self.assertEqual(self.baseline['expected']['next_undo_event'], 'upgrade-active-second:event')

    def test_authentic_audit_order_receipts_and_existing_undo(self):
        audits = list(self.database.execute('SELECT * FROM audit_logs ORDER BY rowid'))
        receipts = [r for r in audits if r['action'] == 'command']
        self.assertEqual(len(receipts), len(self.baseline['commands']))
        for receipt in receipts:
            before, after = json.loads(receipt['before_json']), json.loads(receipt['after_json'])
            self.assertRegex(before['fingerprint'], r'^[0-9a-f]{64}$')
            self.assertTrue(after['committed'])
            self.assertIn('projection', after)
            command = next(command for command in self.baseline['commands']
                           if command['payload']['commandId'] == receipt['id'])
            self.assertEqual(before['fingerprint'], command['fingerprint'])
            fingerprint_payload = {'commandType': command['commandType'], **command['payload']}
            self.assertEqual(before['fingerprint'], hashlib.sha256(json.dumps(
                fingerprint_payload, ensure_ascii=False, separators=(',', ':'),
            ).encode()).hexdigest())
        active_creates = [r['target_id'] for r in audits
                          if r['match_id'] == 'upgrade-active' and r['action'] == 'create'
                          and ':event' in r['target_id']]
        self.assertEqual(active_creates[-2:], [
            'upgrade-active-first:event', 'upgrade-active-second:event',
        ])
        first_time, second_time = [self.database.execute(
            'SELECT occurred_at FROM match_events WHERE id=?', (name,),
        ).fetchone()[0] for name in active_creates[-2:]]
        self.assertLess(second_time, first_time)
        self.assertEqual(self.database.execute(
            "SELECT is_deleted FROM match_events WHERE id='upgrade-history-undone:event'"
        ).fetchone()[0], 1)
        self.assertTrue(any(r['action'] == 'undo' for r in audits))

    def test_refuses_existing_output_and_detects_original_row_mutation(self):
        refused = subprocess.run(
            [sys.executable, str(TOOL), '--output', str(self.output)],
            cwd=ROOT, capture_output=True, text=True,
        )
        self.assertNotEqual(refused.returncode, 0)
        self.assertIn('already exists', refused.stderr)
        valid = subprocess.run([
            sys.executable, str(TOOL), '--verify', str(self.output / 'hooptrace.sqlite'),
            '--baseline', str(self.output / 'baseline.json'), '--expected-schema', '2',
        ], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(valid.returncode, 0, valid.stderr)
        copy = Path(self.temporary.name) / 'mutated.sqlite'
        with closing(sqlite3.connect(copy)) as destination:
            self.database.backup(destination)
            destination.execute("UPDATE matches SET tracking_coverage='full' WHERE id='upgrade-history-scores'")
            destination.commit()
        mutated = subprocess.run([
            sys.executable, str(TOOL), '--verify', str(copy),
            '--baseline', str(self.output / 'baseline.json'), '--expected-schema', '2',
        ], cwd=ROOT, capture_output=True, text=True)
        self.assertNotEqual(mutated.returncode, 0)
        self.assertIn('matches', mutated.stderr)


if __name__ == '__main__':
    unittest.main()
