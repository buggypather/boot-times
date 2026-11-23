// Turns the npm command's arguments into arguments for boot-times.ps1.
// Accepts: boot-times [count] [-n|--count N] [--json] [--no-elevate] [-h|--help] [-v|--version]

export const usage = `Usage: boot-times [count] [options]

Shows how long this PC took to start up over its last boots, and what slowed them down.
Reads the boot record Windows already keeps, so it needs admin rights: if this terminal
isn't admin, Windows asks, and the result still appears here.

Options:
  -n, --count N    how many boots to show (1-1000, default 15)
      --json       print JSON instead of a table
      --no-elevate don't ask for admin rights; fail instead
  -h, --help       show this help
  -v, --version    show the version`;

export function parseArgs(argv) {
  const out = { help: false, version: false, count: undefined, json: false, noElevate: false, error: null };
  const setCount = (value) => {
    if (!/^\d+$/.test(value ?? '') || Number(value) < 1 || Number(value) > 1000) {
      out.error = `The count has to be a whole number from 1 to 1000, not "${value ?? ''}".`;
      return;
    }
    out.count = Number(value);
  };
  for (let i = 0; i < argv.length && !out.error; i++) {
    const arg = argv[i];
    if (arg === '-h' || arg === '--help' || arg === '/?') out.help = true;
    else if (arg === '-v' || arg === '--version') out.version = true;
    else if (arg === '--json') out.json = true;
    else if (arg === '--no-elevate') out.noElevate = true;
    else if (arg === '-n' || arg === '--count') setCount(argv[++i]);
    else if (arg.startsWith('--count=')) setCount(arg.slice('--count='.length));
    else if (/^\d+$/.test(arg)) setCount(arg);
    else out.error = `Unknown option "${arg}". Try boot-times --help.`;
  }
  return out;
}

export function powershellArgs(script, options) {
  const args = ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', script];
  if (options.count !== undefined) args.push('-Count', String(options.count));
  if (options.json) args.push('-Json');
  if (options.noElevate) args.push('-NoElevate');
  return args;
}
