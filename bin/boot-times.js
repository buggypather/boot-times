#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs, powershellArgs, usage } from '../lib/args.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const options = parseArgs(process.argv.slice(2));

if (options.error) {
  console.error(options.error);
  process.exit(2);
}
if (options.help) {
  console.log(usage);
  process.exit(0);
}
if (options.version) {
  console.log(JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version);
  process.exit(0);
}
if (process.platform !== 'win32') {
  console.error('boot-times reads the Windows boot record, so it only runs on Windows.');
  process.exit(1);
}

const child = spawn('powershell.exe', powershellArgs(join(root, 'boot-times.ps1'), options), { stdio: 'inherit' });
child.on('error', (err) => {
  console.error(`Couldn't start Windows PowerShell: ${err.message}`);
  process.exit(1);
});
child.on('exit', (code) => process.exit(code ?? 1));
