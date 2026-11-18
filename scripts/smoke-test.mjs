// Smoke test: drive godot-mcp over stdio like Claude would.
import { pathToFileURL } from 'url';
import { join, dirname } from 'path';
import { tmpdir } from 'os';
import { fileURLToPath } from 'url';
import { mkdirSync, writeFileSync, rmSync } from 'fs';

// Usage: GODOT_PATH=<godot.exe> node scripts/smoke-test.mjs   (needs a prior npm run build)
const repo = join(dirname(fileURLToPath(import.meta.url)), '..');
const godot = process.env.GODOT_PATH;
if (!godot) { console.error('Set GODOT_PATH to your Godot executable'); process.exit(1); }
const proj = join(tmpdir(), 'godot-mcp-smoke');
const sdk = (p) => import(pathToFileURL(join(repo, 'node_modules/@modelcontextprotocol/sdk/dist', p)).href);
const { Client } = await sdk('client/index.js');
const { StdioClientTransport } = await sdk('client/stdio.js');

rmSync(proj, { recursive: true, force: true });
mkdirSync(proj, { recursive: true });
writeFileSync(join(proj, 'project.godot'), 'config_version=5\n\n[application]\nconfig/name="SmokeTest"\nrun/main_scene="res://main.tscn"\n');
writeFileSync(join(proj, 'hello.gd'), 'extends Node2D\nfunc _ready():\n\tprint("HELLO_FROM_GODOT")\n\tget_tree().quit()\n');

const transport = new StdioClientTransport({
  command: process.execPath,
  args: [join(repo, 'build/index.js')],
  env: { ...process.env, GODOT_PATH: godot },
});
const client = new Client({ name: 'smoke', version: '0' }, { capabilities: {} });
await client.connect(transport);

const show = (label, r) => console.log(`\n== ${label} ==\n` + (r.content?.map((c) => c.text).join('\n') ?? JSON.stringify(r)).slice(0, 600));
const call = async (name, args = {}) => {
  try { show(name, await client.callTool({ name, arguments: args })); }
  catch (e) { console.log(`\n== ${name} == ERROR: ${e.message}`); }
};

const { tools } = await client.listTools();
console.log('TOOLS:', tools.map((t) => t.name).join(', '));
await call('get_godot_version');
await call('get_project_info', { projectPath: proj });
await call('create_scene', { projectPath: proj, scenePath: 'main.tscn', rootNodeType: 'Node2D' });
await call('add_node', { projectPath: proj, scenePath: 'main.tscn', nodeType: 'Sprite2D', nodeName: 'Player' });
await call('get_uid', { projectPath: proj, filePath: 'main.tscn' });
await call('update_project_uids', { projectPath: proj });
await call('get_uid', { projectPath: proj, filePath: 'main.tscn' });
await call('get_uid', { projectPath: proj, filePath: 'hello.gd' });
await call('run_project', { projectPath: proj, scene: 'main.tscn' });
await new Promise((r) => setTimeout(r, 6000));
await call('get_debug_output');
await call('stop_project');
await client.close();
process.exit(0);
