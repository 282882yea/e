'use strict';
// Assembles frekksec-sakura.lua: header, the Sakura UI library (wrapped so it returns
// the library table), then frekksec/src/*.lua in numeric order.
//
//   node tools/build-frekksec.js

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const SRC = path.join(ROOT, 'frekksec', 'src');

const parts = fs.readdirSync(SRC).filter((f) => f.endsWith('.lua')).sort();
const read = (file) => fs.readFileSync(file, 'utf8').replace(/\s+$/, '') + '\n';

let out = read(path.join(SRC, parts[0])); // 00-header
out += '\nlocal Sakura = (function()\n' + read(path.join(ROOT, 'Sakura.lua')) + 'end)()\n\n';
for (const part of parts.slice(1)) out += read(path.join(SRC, part)) + '\n';

// Embed the logo layers as base64.
const b64 = (file) => fs.readFileSync(path.join(ROOT, 'frekksec', 'assets', file)).toString('base64');
out = out.replace('__LOGO_TEXT_B64__', () => b64('logo-text.png')).replace('__LOGO_GLOW_B64__', () => b64('logo-glow.png'));

const target = path.join(ROOT, 'frekksec-sakura.lua');
fs.writeFileSync(target, out);
console.log(parts.join(', '));
console.log(`frekksec-sakura.lua: ${(out.length / 1024).toFixed(1)} KB, ${out.split('\n').length} lines`);
