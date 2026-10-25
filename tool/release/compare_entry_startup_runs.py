"""Compare complete, same-source startup batches without connecting to a device.

Metrics are recomputed from every raw run JSON with the production measurement
parser and nearest-rank aggregator. Budget outcomes and repeated-batch variation
are independent: a consistent failure is still a failure, and an inconsistent
pass is not evidence of a stable environment. An optional variation threshold
is diagnostic only; this tool does not add a release stability requirement.
"""

import argparse
import hashlib
import importlib.util
import json
import math
import pathlib
import re


SPEC = importlib.util.spec_from_file_location(
    'entry_startup_measurement', pathlib.Path(__file__).with_name('measure_entry_startup.py'),
)
measurement = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(measurement)

DEVICE_FIELDS = ('serial', 'android_user', 'api', 'abi', 'size', 'density', 'model')


def read_json(path):
    data = path.read_bytes()
    decoded = json.loads(data)
    if not isinstance(decoded, dict):
        raise ValueError(f'{path}: expected a JSON object.')
    return decoded, {'path': str(path.resolve()), 'sha256': hashlib.sha256(data).hexdigest()}


def load_batch(directory):
    directory = pathlib.Path(directory).resolve()
    provenance, provenance_input = read_json(directory / 'provenance.json')
    metadata, aggregate_input = read_json(directory / 'aggregate.json')
    source = provenance.get('source_commit', '')
    apk = provenance.get('profile_apk_sha256', '').lower()
    if not re.fullmatch(r'[0-9a-f]{40}', source):
        raise ValueError(f'{directory}: full application source SHA is required.')
    if not re.fullmatch(r'[0-9a-f]{64}', apk):
        raise ValueError(f'{directory}: APK SHA-256 is required.')
    installed = provenance.get('verified_installed_apk', {})
    if not isinstance(installed, dict) or installed.get('sha256', '').lower() != apk:
        raise ValueError(f'{directory}: installed APK does not match provenance.')
    if provenance.get('recording_during_measurement') is not False:
        raise ValueError(f'{directory}: measurement must explicitly exclude recording.')
    device = provenance.get('device', {})
    if (not isinstance(device, dict)
            or any(field not in device or device[field] in (None, '') for field in DEVICE_FIELDS)):
        raise ValueError(f'{directory}: incomplete device identity.')
    if metadata.get('provenance') != provenance:
        raise ValueError(f'{directory}: aggregate and standalone provenance differ.')
    requested_runs = metadata.get('requested_runs')
    if type(requested_runs) is not int or requested_runs < 1:
        raise ValueError(f'{directory}: requested_runs must be a positive integer.')
    budget_ms = metadata.get('budget_ms')
    if (type(budget_ms) not in (int, float) or not math.isfinite(budget_ms)
            or budget_ms <= 0):
        raise ValueError(f'{directory}: budget_ms must be finite and positive.')
    if metadata.get('collection_error') is not None or (directory / 'collection-error.json').exists():
        raise ValueError(f'{directory}: collection failed; cannot compare partial batches.')
    expected_names = {f'run-{index:02}.json' for index in range(1, requested_runs + 1)}
    actual_names = {path.name for path in directory.glob('run-*.json')}
    if expected_names != actual_names:
        raise ValueError(f'{directory}: raw run files do not match the complete requested batch.')
    probes = []
    inputs = [provenance_input, aggregate_input]
    pids = set()
    for index in range(1, requested_runs + 1):
        raw, raw_input = read_json(directory / f'run-{index:02}.json')
        inputs.append(raw_input)
        if (not isinstance(raw.get('frames'), list) or not isinstance(raw.get('summary'), dict)
                or not isinstance(raw.get('launch'), dict)
                or not isinstance(raw.get('preparation_spans', []), list)):
            raise ValueError(f'{directory}: run {index} has malformed raw records.')
        records = [*raw.get('preparation_spans', []), *raw['frames'], raw['summary']]
        if any(not isinstance(record, dict) for record in records):
            raise ValueError(f'{directory}: run {index} has malformed raw records.')
        probe = measurement.parse_records('\n'.join(
            measurement.PREFIX + json.dumps(record, allow_nan=False) for record in records
        ))
        launch = raw.get('launch', {})
        pid = launch.get('pid')
        if (launch.get('run') != index or launch.get('force_stop_verified') is not True
                or type(pid) is not int or pid <= 0 or pid in pids
                or pid in launch.get('previous_pids', [])):
            raise ValueError(f'{directory}: run {index} lacks a distinct verified cold process.')
        pids.add(pid)
        handoffs = [mark for mark in probe['summary']['marks'] if mark['phase'] == 'handoff']
        if len(handoffs) != 1 or not measurement.phase_frames(probe)['presented']:
            raise ValueError(f'{directory}: run {index} lacks presented handoff samples.')
        probes.append(probe)
    report = measurement.aggregate(probes, budget_ms)
    standard = measurement.evaluate_gates(probes, report, True, False)
    if not standard['passed']:
        raise ValueError(f'{directory}: every requested run must play standard motion without skip/fallback.')
    budget = measurement.evaluate_gates(probes, report, False, True)
    return {
        'directory': str(directory),
        'identity': {'source_commit': source, 'profile_apk_sha256': apk,
                     'device': {field: device[field] for field in DEVICE_FIELDS}},
        'requested_runs': requested_runs, 'budget_ms': budget_ms,
        'report': report, 'budget_outcome': budget, 'inputs': inputs,
    }


def compare_batches(directories, max_relative_range_percent=None):
    if len(directories) < 2:
        raise ValueError('At least two independent measurement directories are required.')
    if max_relative_range_percent is not None and (
            not math.isfinite(max_relative_range_percent) or max_relative_range_percent < 0):
        raise ValueError('Diagnostic variation limit must be finite and nonnegative.')
    resolved = [pathlib.Path(path).resolve() for path in directories]
    if len(set(resolved)) != len(resolved):
        raise ValueError('A repeated directory is not an independent batch.')
    batches = [load_batch(path) for path in resolved]
    first = batches[0]
    for batch in batches[1:]:
        for field in ('identity', 'requested_runs', 'budget_ms'):
            if batch[field] != first[field]:
                raise ValueError(f'Batches differ in {field}; same-source repetition is required.')
    values = [batch['report']['phases']['presented']['raster']['p95_ms'] for batch in batches]
    average = sum(values) / len(values)
    spread = max(values) - min(values)
    relative = spread / average * 100 if average else 0.0
    return {
        'status': 'compared', 'identity': first['identity'],
        'batch_count': len(batches), 'requested_runs_per_batch': first['requested_runs'],
        'budget_ms': first['budget_ms'], 'budget_phase': 'presented',
        'all_batches_within_budget': all(batch['budget_outcome']['passed'] for batch in batches),
        'raster_p95_repetition': {
            'values_ms': values, 'min_ms': min(values), 'max_ms': max(values),
            'range_ms': spread, 'mean_ms': average, 'relative_range_percent': relative,
            'relative_range_method': '(maximum batch p95 - minimum batch p95) / mean batch p95 * 100',
        },
        'variation_diagnostic': {
            'max_relative_range_percent': max_relative_range_percent,
            'within_requested_limit': None if max_relative_range_percent is None
                                     else relative <= max_relative_range_percent,
            'release_gate': False,
        },
        'limitations': [
            'Device identity contains only fields recorded by the measurement collector; '
            'boot, GPU, transport, host load and thermal continuity require separate evidence.',
            'Repeated-batch variation and build/raster budget outcomes are independent; '
            'this report does not establish physical-device performance or release readiness.',
        ],
        'batches': batches,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directories', nargs='+', type=pathlib.Path)
    parser.add_argument('--output', required=True, type=pathlib.Path,
                        help='New comparison JSON; existing evidence is never overwritten.')
    parser.add_argument('--max-relative-range-percent', type=float,
                        help='Optional diagnostic limit, not a release gate.')
    parser.add_argument('--enforce-budget', action='store_true',
                        help='Return 1 if any recomputed complete batch exceeds its unchanged budget.')
    args = parser.parse_args(argv)
    if args.output.exists():
        parser.error('output must be a new file; existing evidence is never overwritten')
    try:
        report = compare_batches(args.directories, args.max_relative_range_percent)
    except (ValueError, KeyError, TypeError, AttributeError, OSError) as error:
        report = {'status': 'comparison_invalid', 'error_type': type(error).__name__,
                  'message': str(error), 'directories': [str(path.resolve()) for path in args.directories]}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open('x', encoding='utf-8') as output:
        output.write(json.dumps(report, indent=2, allow_nan=False) + '\n')
    print(json.dumps({key: value for key, value in report.items() if key != 'batches'}, indent=2))
    if report['status'] != 'compared':
        return 2
    diagnostic_failed = report['variation_diagnostic']['within_requested_limit'] is False
    return int(diagnostic_failed or args.enforce_budget and not report['all_batches_within_budget'])


if __name__ == '__main__':
    raise SystemExit(main())
