'use strict';
// Bakes the backdrop from tools/scene.js into Sakura.lua (between the
// <scene-data> markers) and assembles sakura-standalone.lua.
//
//   node tools/build.js

const fs = require('fs');
const path = require('path');
const { generate } = require('./scene.js');

const ROOT = path.join(__dirname, '..');
const ALPHABET = '0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
const MAX = ALPHABET.length - 1; // largest width/height one character can hold

function two(n) {
	if (n < 0 || n >= ALPHABET.length * ALPHABET.length) throw new Error(`coordinate out of range: ${n}`);
	return ALPHABET[Math.floor(n / ALPHABET.length)] + ALPHABET[n % ALPHABET.length];
}

// 7 characters per rectangle: x (2), y (2), width, height, palette slot.
// Rectangles too large for one character are split.
function encode(rects) {
	let out = '';
	let count = 0;
	for (const [x, y, w, h, c] of rects) {
		for (let oy = 0; oy < h; oy += MAX) {
			for (let ox = 0; ox < w; ox += MAX) {
				out += two(x + ox) + two(y + oy) + ALPHABET[Math.min(MAX, w - ox)] + ALPHABET[Math.min(MAX, h - oy)] + ALPHABET[c];
				count++;
			}
		}
	}
	return { data: out, count };
}

function sceneBlock() {
	const scene = generate();
	if (scene.slots.length > ALPHABET.length) throw new Error('too many palette slots');
	const lines = [];
	let total = 0;
	lines.push('-- Written by tools/build.js. Edit tools/scene.js instead of this block.');
	lines.push(`local SCENE_SLOTS = { ${scene.slots.map((s) => `"${s}"`).join(', ')} }`);
	lines.push('-- { rows above the bottom edge, height in rows, palette key }');
	lines.push(`local SCENE_STRIPS = { ${scene.strips.map((s) => `{ ${s.fromBottom}, ${s.height}, "${s.key}" }`).join(', ')} }`);
	lines.push('-- { anchor, width, height, rectangles }');
	lines.push('local SCENE_GROUPS = {');
	for (const g of scene.groups) {
		const { data, count } = encode(g.rects);
		total += count;
		lines.push(`\t{ "${g.anchor}", ${g.w}, ${g.h}, "${data}" }, -- ${g.name}: ${count} rectangles`);
	}
	lines.push('}');
	lines.push('-- Colours are RRGGBB or RRGGBBAA (AA = opacity).');
	lines.push('local SCENE_PALETTES = {');
	for (const [name, pal] of Object.entries(scene.palettes)) {
		lines.push(`\t${name} = {`);
		lines.push(`\t\tsky = { ${pal.sky.map((c) => `"${c}"`).join(', ')} },`);
		const keys = Object.keys(pal).filter((k) => k !== 'sky');
		for (let i = 0; i < keys.length; i += 4) {
			lines.push('\t\t' + keys.slice(i, i + 4).map((k) => `${k} = "${pal[k]}",`).join(' '));
		}
		lines.push('\t},');
	}
	lines.push('}');
	return { text: lines.join('\n'), total };
}

function replaceBetween(source, open, close, body) {
	const a = source.indexOf(open);
	const b = source.indexOf(close);
	if (a < 0 || b < 0 || b < a) throw new Error(`markers ${open} / ${close} not found`);
	return source.slice(0, a + open.length) + '\n' + body + '\n' + source.slice(b);
}

const libPath = path.join(ROOT, 'Sakura.lua');
const block = sceneBlock();
const library = replaceBetween(fs.readFileSync(libPath, 'utf8'), '-- <scene-data>', '-- </scene-data>', block.text);
fs.writeFileSync(libPath, library);

// Standalone: the library inlined ahead of the example, so the whole thing
// can be pasted into an executor without an HTTP request.
const example = fs.readFileSync(path.join(ROOT, 'sakura-example.lua'), 'utf8');
const loadLine = /^local Sakura = loadstring\(.*$/m;
if (!loadLine.test(example)) throw new Error('sakura-example.lua: loadstring line not found');
const body = example
	.replace(/^-- Sakura UI example\..*\n/, '')
	.replace(loadLine, '');
const standalone =
	'-- Sakura UI standalone: library + example in one file. Paste the whole thing into your executor.\n' +
	'local Sakura = (function()\n' +
	library.replace(/\s+$/, '') +
	'\nend)()\n' +
	body.replace(/^\n+/, '\n');
fs.writeFileSync(path.join(ROOT, 'sakura-standalone.lua'), standalone);

console.log(`scene: ${block.total} rectangles`);
console.log(`Sakura.lua: ${(library.length / 1024).toFixed(1)} KB`);
console.log(`sakura-standalone.lua: ${(standalone.length / 1024).toFixed(1)} KB`);
