import test from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync, spawnSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { parseArgs, powershellArgs } from '../lib/args.js';

test('no arguments uses the defaults', () => {
  const o = parseArgs([]);
  assert.equal(o.error, null);
  assert.equal(o.count, undefined);
  assert.deepEqual(powershellArgs('s.ps1', o), ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', 's.ps1']);
});

test('count can be given three ways', () => {
  for (const argv of [['40'], ['-n', '40'], ['--count', '40'], ['--count=40']]) {
    assert.equal(parseArgs(argv).count, 40, argv.join(' '));
  }
});

test('flags map to PowerShell switches', () => {
  const o = parseArgs(['--json', '--no-elevate', '-n', '3']);
  assert.deepEqual(powershellArgs('s.ps1', o).slice(5), ['-Count', '3', '-Json', '-NoElevate']);
});

test('bad counts and unknown options are errors', () => {
  for (const argv of [['0'], ['1001'], ['-n'], ['-n', 'x'], ['--count=2.5'], ['--fast']]) {
    assert.ok(parseArgs(argv).error, argv.join(' '));
  }
});

test('help and version', () => {
  assert.equal(parseArgs(['-h']).help, true);
  assert.equal(parseArgs(['--version']).version, true);
});

test('the command prints help and version without PowerShell', () => {
  const help = execFileSync(process.execPath, ['bin/boot-times.js', '--help'], { encoding: 'utf8' });
  assert.match(help, /Usage: boot-times/);
  const version = execFileSync(process.execPath, ['bin/boot-times.js', '-v'], { encoding: 'utf8' }).trim();
  assert.equal(version, JSON.parse(readFileSync('package.json', 'utf8')).version);
  const bad = spawnSync(process.execPath, ['bin/boot-times.js', '--fast'], { encoding: 'utf8' });
  assert.equal(bad.status, 2);
});

test('the npm and PowerShell Gallery versions match', () => {
  const npm = JSON.parse(readFileSync('package.json', 'utf8')).version;
  const psd1 = readFileSync('BootTimes/BootTimes.psd1', 'utf8').match(/ModuleVersion\s*=\s*'([^']+)'/)[1];
  assert.equal(psd1, npm);
});
