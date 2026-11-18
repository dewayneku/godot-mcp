// End-to-end smoke test: drives the built server over stdio the way an MCP client does.
// Usage (after `npm run build`):
//   PowerShell:  $env:GODOT_PATH = "C:\path\to\Godot.exe"; node scripts/smoke-test.mjs
//   bash:        GODOT_PATH=/path/to/godot node scripts/smoke-test.mjs
// Creates a throwaway project in the OS temp folder, prints each tool's result,
// saves the screenshot next to it and exits non-zero if any expectation fails.
import { pathToFileURL, fileURLToPath } from 'url';
import { join, dirname } from 'path';
import { tmpdir } from 'os';
import { mkdirSync, writeFileSync, rmSync, readFileSync } from 'fs';

const repo = join(dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.env.GODOT_PATH;
if (!godot) {
  console.error('Set GODOT_PATH to your Godot executable');
  process.exit(1);
}
const proj = join(tmpdir(), 'godot-mcp-smoke');
const sdk = (p) => import(pathToFileURL(join(repo, 'node_modules/@modelcontextprotocol/sdk/dist', p)).href);
const { Client } = await sdk('client/index.js');
const { StdioClientTransport } = await sdk('client/stdio.js');

// --- throwaway project ---------------------------------------------------
rmSync(proj, { recursive: true, force: true });
mkdirSync(proj, { recursive: true });
writeFileSync(
  join(proj, 'project.godot'),
  'config_version=5\n\n[application]\nconfig/name="SmokeTest"\nrun/main_scene="res://main.tscn"\n'
);
writeFileSync(
  join(proj, 'icon.svg'),
  '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect width="32" height="32" fill="#ffffff"/></svg>'
);
writeFileSync(join(proj, 'broken.gd'), 'extends Node\nfunc _ready():\n\tvar x: int = "oops"\n\tprint(undefined_thing)\n');

// --- client ----------------------------------------------------------------
const transport = new StdioClientTransport({
  command: process.execPath,
  args: [join(repo, 'build/index.js')],
  env: { ...process.env, GODOT_PATH: godot },
});
const client = new Client({ name: 'smoke', version: '0' }, { capabilities: {} });
await client.connect(transport);

let failures = 0;
const textOf = (r) => (r.content ?? []).filter((c) => c.type === 'text').map((c) => c.text).join('\n');
async function call(name, args, expect) {
  let r;
  try {
    r = await client.callTool({ name, arguments: { projectPath: proj, ...args } });
  } catch (e) {
    r = { isError: true, content: [{ type: 'text', text: `THROWN: ${e.message}` }] };
  }
  const text = textOf(r);
  const ok = expect ? expect(r, text) : !r.isError;
  if (!ok) failures++;
  console.log(`\n== ${name} ${ok ? 'PASS' : 'FAIL'} ==\n${text.slice(0, 900)}`);
  return r;
}

const { tools } = await client.listTools();
console.log('TOOLS:', tools.map((t) => t.name).join(', '));

await call('get_godot_version', {});
await call('get_project_info', {}, (_, t) => t.includes('"SmokeTest"'));
await call('create_scene', { scenePath: 'main.tscn', rootNodeType: 'Node2D' });
await call('add_node', { scenePath: 'main.tscn', nodeType: 'Sprite2D', nodeName: 'Player' });
await call('get_uid', { filePath: 'main.tscn' }, (_, t) => /uid:\/\/\w+/.test(t));

await call(
  'set_node_properties',
  {
    scenePath: 'main.tscn',
    nodePath: 'Player',
    properties: { position: [576, 324], scale: [4, 4], texture: 'res://icon.svg', modulate: '#ff8800', rotation_degrees: 45 },
  },
  (r, t) => !r.isError && t.includes('Vector2(576, 324)')
);
await call(
  'set_node_properties',
  { scenePath: 'main.tscn', nodePath: 'Player', properties: { not_a_property: 1 } },
  (r, t) => r.isError && t.includes('not a property')
);
await call(
  'set_node_properties',
  { scenePath: 'main.tscn', nodePath: 'Nope', properties: { visible: false } },
  (r, t) => r.isError && t.includes('Node not found')
);

await call(
  'attach_script',
  {
    scenePath: 'main.tscn',
    scriptPath: 'scripts/main.gd',
    scriptContent:
      'extends Node2D\n\nfunc _ready() -> void:\n\tprint("HELLO_FROM_SMOKE")\n\nfunc _draw() -> void:\n\tdraw_rect(Rect2(40, 40, 160, 90), Color.CORNFLOWER_BLUE)\n',
  },
  (r, t) => !r.isError && t.includes('attached')
);
await call(
  'attach_script',
  { scenePath: 'main.tscn', nodePath: 'Player', scriptPath: 'scripts/bad.gd', scriptContent: 'extends Node2D\nfunc _ready():\n\tfoo(\n' },
  (r, t) => r.isError && t.includes('errors')
);
await call(
  'attach_script',
  { scenePath: 'main.tscn', nodePath: 'Player', scriptPath: 'scripts/wrong_base.gd', scriptContent: 'extends Control\n' },
  (r, t) => r.isError && t.includes('extends Control')
);

await call('get_scene_tree', { scenePath: 'main.tscn' }, (r, t) => !r.isError && t.includes('"Player"') && t.includes('res://scripts/main.gd'));
await call(
  'validate_scripts',
  {},
  (r, t) => t.includes('broken.gd') && t.includes('line 3') && t.includes('line 4') && !t.includes('main.gd\n')
);
await call('validate_scripts', { scriptPaths: ['scripts/main.gd'] }, (_, t) => t.startsWith('All 1 script(s) OK'));
await call('update_project_uids', {});
await call('get_uid', { filePath: 'scripts/main.gd' }, (_, t) => /uid:\/\/\w+/.test(t));

const shot = await call('take_screenshot', { seconds: 0.5 }, (r) => r.content?.some((c) => c.type === 'image'));
const img = shot.content?.find((c) => c.type === 'image');
if (img) {
  writeFileSync(join(proj, 'screenshot.png'), Buffer.from(img.data, 'base64'));
  console.log(`(screenshot saved to ${join(proj, 'screenshot.png')})`);
}

await call('run_project', { scene: 'main.tscn' });
await new Promise((r) => setTimeout(r, 4000));
await call('get_debug_output', {}, (_, t) => t.includes('HELLO_FROM_SMOKE'));
await call('stop_project', {});

console.log('\n--- main.tscn ---\n' + readFileSync(join(proj, 'main.tscn'), 'utf8'));
console.log(failures === 0 ? '\nALL PASSED' : `\n${failures} FAILED`);
await client.close();
process.exit(failures === 0 ? 0 : 1);
