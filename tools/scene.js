'use strict';
// Generates the pixel-art backdrop for Sakura UI (Tokyo skyline, rose and white
// blossom trees). The output is a list of coloured rectangles per anchor group,
// which tools/build.js bakes into Sakura.lua. Run `node tools/build.js` after
// editing this file.

// Every rectangle refers to a palette slot by index, so a theme can recolour
// the whole scene without regenerating it.
const SLOTS = [
	'orb', 'halo1', 'halo2', 'star', 'cloud', 'cloudShade',
	'fuji', 'fujiShade', 'snow', 'farCity', 'farWindow',
	'tower', 'towerBand', 'towerDark',
	'nearCity', 'nearCity2', 'window', 'window2', 'neon1', 'neon2',
	'waterLight', 'waterDark', 'bankLight',
	'trunk', 'trunkLight',
	'roseDark', 'roseMid', 'roseLight', 'roseHi',
	'whiteDark', 'whiteMid', 'whiteLight', 'whiteHi',
	'lantern', 'lanternGlow', 'leaf', 'wire',
];
const SLOT = {};
SLOTS.forEach((name, i) => { SLOT[name] = i; });

// Colours are RRGGBB or RRGGBBAA (AA = opacity).
const PALETTES = {
	Dusk: {
		sky: ['4a3d8f', '7a58b8', 'c476c4', 'f590b8', 'ffb3b0', 'ffd6b3'],
		water: '6d5cb5', bank: '33204a',
		orb: 'fff3d6', halo1: 'ffffff38', halo2: 'ffffff1c', star: 'ffffffb0',
		cloud: 'ffe6f0e6', cloudShade: 'f5aecfe6',
		fuji: '8a78cc', fujiShade: '7564ba', snow: 'fdf2ff',
		farCity: 'b47fc4', farWindow: 'ffe7a6',
		tower: 'ff5a72', towerBand: 'fff0f0', towerDark: 'c93a5c',
		nearCity: '54356f', nearCity2: '684384', window: 'ffd88a', window2: 'ff9ccb',
		neon1: 'ff6db4', neon2: '7fe9fb',
		waterLight: 'f7a8cdb0', waterDark: '5a4aa3', bankLight: '4d3266',
		trunk: '472838', trunkLight: '6b3f51',
		roseDark: 'bf2f77', roseMid: 'ee5798', roseLight: 'ff8cbd', roseHi: 'ffc6de',
		whiteDark: 'd3a3cd', whiteMid: 'f1cfe4', whiteLight: 'fff0f6', whiteHi: 'ffffff',
		lantern: 'ff5e6c', lanternGlow: 'ffe38f', leaf: '4c8f63', wire: '2a1a3c',
	},
	Night: {
		sky: ['0b0a26', '15113f', '271a5c', '43247a', '6a2f8a', '9a4196'],
		water: '1a1550', bank: '0c0920',
		orb: 'fffbe6', halo1: 'ffffff30', halo2: 'ffffff16', star: 'ffffffd0',
		cloud: '6a5aa8b0', cloudShade: '4a3c88b0',
		fuji: '2c2468', fujiShade: '231c57', snow: 'cfc8f5',
		farCity: '3a2470', farWindow: 'ffe7a6',
		tower: 'ff4f6e', towerBand: 'ffe9c9', towerDark: 'b52c52',
		nearCity: '120d30', nearCity2: '1c1444', window: 'ffd88a', window2: 'ff7fc0',
		neon1: 'ff4fa8', neon2: '5fe6ff',
		waterLight: 'ff7fc080', waterDark: '120f3c', bankLight: '191238',
		trunk: '1f1226', trunkLight: '3a2240',
		roseDark: '9a2468', roseMid: 'd9478c', roseLight: 'ff7fb6', roseHi: 'ffc0dc',
		whiteDark: '9c86c8', whiteMid: 'd6c4ec', whiteLight: 'f6eeff', whiteHi: 'ffffff',
		lantern: 'ff5e6c', lanternGlow: 'ffe38f', leaf: '2f6b55', wire: '07051a',
	},
	Day: {
		sky: ['7fc2ff', 'a3d4ff', 'c9e2ff', 'ecdcff', 'ffd6ea', 'ffeedd'],
		water: '8fd0f2', bank: '6fbf86',
		orb: 'fffbe0', halo1: 'ffffff60', halo2: 'ffffff30', star: 'ffffff00',
		cloud: 'fffffff0', cloudShade: 'e4d4f7f0',
		fuji: '93addf', fujiShade: '7f99d0', snow: 'ffffff',
		farCity: 'c7b0e6', farWindow: 'fff6cf',
		tower: 'ff6680', towerBand: 'ffffff', towerDark: 'd9486a',
		nearCity: '9a80cc', nearCity2: 'ad94da', window: 'fff3c2', window2: 'ffc2de',
		neon1: 'ff7fbd', neon2: '8ff0ff',
		waterLight: 'ffffffa0', waterDark: '70b8e2', bankLight: '8cd49b',
		trunk: '6b4334', trunkLight: '8e5f4b',
		roseDark: 'd13d86', roseMid: 'f565a4', roseLight: 'ff9cc8', roseHi: 'ffd3e6',
		whiteDark: 'e3b6d6', whiteMid: 'f8dcec', whiteLight: 'fff5fa', whiteHi: 'ffffff',
		lantern: 'ff6b78', lanternGlow: 'fff0a8', leaf: '4fa36a', wire: '5d4a7a',
	},
};

// ---------------------------------------------------------------------------

function mulberry32(seed) {
	let a = seed >>> 0;
	return function () {
		a = (a + 0x6d2b79f5) >>> 0;
		let t = a;
		t = Math.imul(t ^ (t >>> 15), t | 1);
		t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
		return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
	};
}

class Grid {
	constructor(w, h) {
		this.w = w;
		this.h = h;
		this.d = new Int16Array(w * h).fill(-1);
	}
	set(x, y, c) {
		x = Math.round(x);
		y = Math.round(y);
		if (x >= 0 && y >= 0 && x < this.w && y < this.h) this.d[y * this.w + x] = c;
	}
	get(x, y) {
		x = Math.round(x);
		y = Math.round(y);
		if (x < 0 || y < 0 || x >= this.w || y >= this.h) return -1;
		return this.d[y * this.w + x];
	}
	rect(x, y, w, h, c) {
		for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, c);
	}
	disc(cx, cy, r, c) {
		if (r <= 0) return;
		const r2 = r * r;
		for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) {
			for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) {
				const dx = x - cx, dy = y - cy;
				if (dx * dx + dy * dy <= r2) this.set(x, y, c);
			}
		}
	}
	ellipse(cx, cy, rx, ry, c) {
		for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) {
			for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
				const dx = (x - cx) / rx, dy = (y - cy) / ry;
				if (dx * dx + dy * dy <= 1) this.set(x, y, c);
			}
		}
	}
}

// Greedy rectangle merge: widest run first, then extended downwards.
function mesh(grid) {
	const { w, h, d } = grid;
	const used = new Uint8Array(w * h);
	const rects = [];
	for (let y = 0; y < h; y++) {
		for (let x = 0; x < w; x++) {
			const c = d[y * w + x];
			if (c < 0 || used[y * w + x]) continue;
			let rw = 1;
			while (x + rw < w && d[y * w + x + rw] === c && !used[y * w + x + rw]) rw++;
			let rh = 1;
			outer: while (y + rh < h) {
				for (let i = 0; i < rw; i++) {
					const k = (y + rh) * w + x + i;
					if (d[k] !== c || used[k]) break outer;
				}
				rh++;
			}
			for (let j = 0; j < rh; j++) for (let i = 0; i < rw; i++) used[(y + j) * w + x + i] = 1;
			rects.push([x, y, rw, rh, c]);
		}
	}
	return rects;
}

// A group is a stack of grids sharing one anchor; later layers draw on top.
class Group {
	constructor(name, anchor, w, h) {
		this.name = name;
		this.anchor = anchor;
		this.w = w;
		this.h = h;
		this.layers = [];
	}
	layer() {
		const g = new Grid(this.w, this.h);
		this.layers.push(g);
		return g;
	}
	rects() {
		let all = [];
		this.counts = [];
		for (const g of this.layers) {
			const r = mesh(g);
			this.counts.push(r.length);
			all = all.concat(r);
		}
		return all;
	}
}

// ---------------------------------------------------------------------------
// Blossom trees
// ---------------------------------------------------------------------------

function tones(kind) {
	return kind === 'rose'
		? [SLOT.roseDark, SLOT.roseMid, SLOT.roseLight, SLOT.roseHi]
		: [SLOT.whiteDark, SLOT.whiteMid, SLOT.whiteLight, SLOT.whiteHi];
}

// One clump of blossom, lit from the top left.
function puff(g, cx, cy, r, t) {
	g.disc(cx, cy, r, t[0]);
	g.disc(cx - 0.8, cy - 0.9, r - 1.3, t[1]);
	if (r >= 4.6) g.disc(cx - 1.6, cy - 1.8, r - 3.1, t[2]);
}

// Highlights go on their own layer: one rectangle each, without splitting the
// runs underneath.
function sparkle(g, over, puffs, t, rng, density) {
	for (const p of puffs) {
		const n = Math.round(p.r * density);
		for (let i = 0; i < n; i++) {
			const a = rng() * Math.PI * 2;
			const d = rng() * p.r * 0.75;
			const x = Math.round(p.x - 1.5 + Math.cos(a) * d);
			const y = Math.round(p.y - 1.5 + Math.sin(a) * d);
			const under = g.get(x, y);
			if (under === t[2]) over.set(x, y, t[3]);
			else if (under === t[1] && rng() < 0.5) over.set(x, y, t[2]);
		}
	}
}

function limb(g, x, y, angle, length, thick, curve, rng, nodes, depth) {
	const steps = Math.max(2, Math.round(length));
	for (let i = 0; i < steps; i++) {
		const k = i / steps;
		const th = thick * (1 - 0.45 * k);
		x += Math.cos(angle);
		y += Math.sin(angle);
		angle += curve + (rng() - 0.5) * 0.08;
		const half = Math.max(0.5, th / 2);
		g.disc(x, y, half, SLOT.trunk);
		if (th >= 3) g.set(x - half * 0.55, y, SLOT.trunkLight);
	}
	nodes.push({ x, y, depth });
	return { x, y, angle };
}

function grow(g, x, y, angle, length, thick, depth, rng, nodes, spread) {
	const end = limb(g, x, y, angle, length, thick, (rng() - 0.5) * 0.02, rng, nodes, depth);
	if (depth <= 0) return;
	const kids = depth >= 2 ? 3 : 2;
	for (let i = 0; i < kids; i++) {
		const side = kids === 1 ? 0 : (i / (kids - 1)) * 2 - 1;
		const a = end.angle + side * spread * (0.75 + rng() * 0.5) + (rng() - 0.5) * 0.2;
		grow(g, end.x, end.y, a, length * (0.58 + rng() * 0.2), Math.max(1, thick * 0.62), depth - 1, rng, nodes, spread);
	}
}

function bigTree(group, kind, opts, rng) {
	const wood = group.layer();
	const leaves = group.layer();
	const shine = group.layer();
	const t = tones(kind);
	const nodes = [];

	// roots flare
	for (let i = 0; i < 5; i++) {
		wood.disc(opts.x - 5 + i * 2.5, opts.y - 1 - (i === 2 ? 2 : 0), 2.2, SLOT.trunk);
	}
	grow(wood, opts.x, opts.y, -Math.PI / 2 + opts.lean, opts.trunk, opts.thick, 3, rng, nodes, 0.62);

	// Blossom clumps at every branch end, plus fill inside the canopy ellipse
	// so the crown reads as one mass.
	const puffs = [];
	for (const n of nodes) {
		if (n.depth >= 3) continue;
		if (n.depth === 0 && rng() < 0.3) continue;
		const r = n.depth === 0 ? 5.5 + rng() * 3.5 : 4.6 + rng() * 3;
		puffs.push({ x: n.x, y: n.y, r });
	}
	for (let i = 0; i < opts.fill; i++) {
		const a = rng() * Math.PI * 2;
		const d = Math.sqrt(rng());
		puffs.push({
			x: opts.cx + Math.cos(a) * d * opts.rx,
			y: opts.cy + Math.sin(a) * d * opts.ry,
			r: 5 + rng() * 4.5,
		});
	}
	puffs.sort((a, b) => a.y - b.y);
	for (const p of puffs) puff(leaves, p.x, p.y, p.r, t);
	sparkle(leaves, shine, puffs, t, rng, 0.55);

	// A few boughs showing through the blossom.
	for (const n of nodes) {
		if (n.depth === 1 && rng() < 0.6) {
			const len = 2 + Math.floor(rng() * 4);
			for (let i = 0; i < len; i++) shine.set(n.x + i * opts.dir, n.y + 2 + Math.floor(i / 2), SLOT.trunk);
		}
	}
	// Loose petals drifting below the crown.
	for (let i = 0; i < opts.drift; i++) {
		const x = opts.cx + (rng() - 0.5) * opts.rx * 2.2;
		const y = opts.cy + opts.ry * (0.9 + rng() * 0.9);
		if (wood.get(x, y) < 0 && leaves.get(x, y) < 0) shine.set(x, y, rng() < 0.5 ? t[2] : t[1]);
	}
}

function smallTree(wood, leaves, over, x, y, h, r, kind, rng) {
	const t = tones(kind);
	for (let i = 0; i < h; i++) {
		wood.set(x, y - i, SLOT.trunk);
		if (i < h * 0.5) wood.set(x + 1, y - i, SLOT.trunk);
	}
	wood.set(x - 1, y, SLOT.trunk);
	wood.set(x + 2, y, SLOT.trunk);
	const puffs = [];
	const cy = y - h - r * 0.5;
	puffs.push({ x, y: cy, r });
	for (let i = 0; i < 5; i++) {
		const a = rng() * Math.PI * 2;
		puffs.push({ x: x + Math.cos(a) * r * 0.75, y: cy + Math.sin(a) * r * 0.55, r: r * (0.55 + rng() * 0.3) });
	}
	puffs.sort((a, b) => a.y - b.y);
	for (const p of puffs) puff(leaves, p.x, p.y, p.r, t);
	sparkle(leaves, over, puffs, t, rng, 0.5);
}

// A bough reaching in from a top corner.
function hangingBranch(group, kind, dir, rng) {
	const wood = group.layer();
	const leaves = group.layer();
	const shine = group.layer();
	const t = tones(kind);
	const startX = dir > 0 ? 0 : group.w - 1;
	const puffs = [];
	const boughs = [
		{ y: 3, angle: 0.2, len: group.w * 0.82, thick: 3 },
		{ y: 12, angle: 0.48, len: group.w * 0.45, thick: 2 },
	];
	for (const b of boughs) {
		let x = startX, y = b.y, angle = b.angle;
		const steps = Math.round(b.len);
		for (let i = 0; i < steps; i++) {
			const k = i / steps;
			x += Math.cos(angle) * dir;
			y += Math.sin(angle);
			angle += 0.004 + (rng() - 0.5) * 0.04;
			wood.disc(x, y, Math.max(0.5, (b.thick * (1 - k * 0.7)) / 2), SLOT.trunk);
			if (i % 7 === 3) {
				puffs.push({
					x: x + (rng() - 0.5) * 5,
					y: y + (rng() - 0.3) * 6,
					r: 2.6 + rng() * 3.4 * (1 - k * 0.5),
				});
			}
			// twigs hanging down
			if (i % 11 === 7 && k > 0.15) {
				const len = 3 + Math.floor(rng() * 6);
				for (let j = 1; j <= len; j++) wood.set(x + (j > len / 2 ? dir : 0), y + j, SLOT.trunk);
				puffs.push({ x: x + dir, y: y + len + 1, r: 2.2 + rng() * 1.6 });
			}
		}
	}
	// Dense blossom in the corner itself.
	for (let i = 0; i < 5; i++) {
		puffs.push({ x: startX + dir * rng() * 18, y: rng() * 10, r: 4.5 + rng() * 3 });
	}
	puffs.sort((a, b) => a.y - b.y);
	for (const p of puffs) puff(leaves, p.x, p.y, p.r, t);
	sparkle(leaves, shine, puffs, t, rng, 0.5);
}

// ---------------------------------------------------------------------------
// City
// ---------------------------------------------------------------------------

function fuji(g, cx, baseY, height, halfBase) {
	const topY = baseY - height;
	for (let y = topY; y <= baseY; y++) {
		const k = (y - topY) / height;
		// concave slopes with a flat-ish crater
		const hw = 3 + (halfBase - 3) * Math.pow(k, 1.45);
		for (let x = Math.round(cx - hw); x <= Math.round(cx + hw); x++) {
			const shaded = x > cx + hw * 0.25;
			g.set(x, y, shaded ? SLOT.fujiShade : SLOT.fuji);
		}
	}
	// snow cap with a ragged lower edge
	const capDepth = Math.round(height * 0.3);
	for (let y = topY; y <= topY + capDepth; y++) {
		const k = (y - topY) / height;
		const hw = 3 + (halfBase - 3) * Math.pow(k, 1.45);
		for (let x = Math.round(cx - hw); x <= Math.round(cx + hw); x++) {
			const tooth = Math.abs(((x - Math.round(cx)) % 6 + 6) % 6 - 3);
			if (y - topY <= capDepth - tooth * 1.6) g.set(x, y, SLOT.snow);
		}
	}
}

function tokyoTower(g, detail, cx, baseY, height) {
	const topY = baseY - height;
	const halfAt = (k) => 0.6 + 12.5 * Math.pow(k, 2.35);
	for (let y = topY; y <= baseY; y++) {
		const k = (y - topY) / height;
		const hw = halfAt(k);
		const band = Math.floor(k * 9) % 2 === 1;
		for (let x = Math.round(cx - hw); x <= Math.round(cx + hw); x++) {
			let c = band ? SLOT.towerBand : SLOT.tower;
			if (!band && x > cx + hw * 0.35) c = SLOT.towerDark;
			g.set(x, y, c);
		}
		// the arch between the legs
		if (k > 0.74) {
			const a = (k - 0.74) / 0.26;
			const inner = (hw - 2.2) * Math.sqrt(Math.min(1, a * 1.25));
			for (let x = Math.round(cx - inner); x <= Math.round(cx + inner); x++) g.set(x, y, -1);
		}
	}
	// observation decks
	const main = Math.round(topY + height * 0.56);
	g.rect(cx - 6, main, 13, 2, SLOT.towerBand);
	g.rect(cx - 6, main + 2, 13, 2, SLOT.towerDark);
	detail.rect(cx - 5, main, 11, 1, SLOT.lanternGlow);
	const top = Math.round(topY + height * 0.2);
	g.rect(cx - 2, top, 5, 3, SLOT.towerBand);
	detail.rect(cx - 2, top + 1, 5, 1, SLOT.lanternGlow);
	// antenna and beacon
	g.rect(cx, topY - 9, 1, 9, SLOT.tower);
	g.rect(cx, topY - 4, 1, 2, SLOT.towerBand);
	detail.set(cx, topY - 10, SLOT.lanternGlow);
	// low building under the tower
	g.rect(cx - 9, baseY - 4, 19, 5, SLOT.nearCity2);
	detail.rect(cx - 7, baseY - 3, 15, 1, SLOT.window);
}

function pagoda(g, detail, cx, baseY) {
	let y = baseY;
	const tiers = [9, 8, 7, 6, 5];
	for (let i = 0; i < tiers.length; i++) {
		const hw = tiers[i];
		g.rect(cx - hw + 2, y - 3, (hw - 2) * 2 + 1, 4, SLOT.nearCity);
		if (i < 4) detail.rect(cx - 1, y - 2, 3, 1, SLOT.window);
		y -= 4;
		// roof with upturned eaves
		g.rect(cx - hw, y, hw * 2 + 1, 1, SLOT.towerDark);
		g.rect(cx - hw + 1, y - 1, (hw - 1) * 2 + 1, 1, SLOT.tower);
		g.set(cx - hw - 1, y - 1, SLOT.towerDark);
		g.set(cx + hw + 1, y - 1, SLOT.towerDark);
		y -= 2;
	}
	g.rect(cx, y - 5, 1, 6, SLOT.nearCity);
	detail.set(cx, y - 6, SLOT.lanternGlow);
}

function skyline(g, detail, x0, x1, baseY, minH, maxH, bodySlots, windowSlots, rng, opts) {
	let x = x0;
	while (x < x1) {
		const w = opts.minW + Math.floor(rng() * (opts.maxW - opts.minW + 1));
		let h = minH + Math.floor(rng() * (maxH - minH + 1));
		if (opts.skip && opts.skip(x, w)) h = Math.min(h, minH + 2);
		const body = bodySlots[Math.floor(rng() * bodySlots.length)];
		g.rect(x, baseY - h, w, h + 1, body);
		const roof = rng();
		if (roof < 0.22 && w >= 6) g.rect(x + 1, baseY - h - 2, w - 2, 2, body);
		else if (roof < 0.36) g.rect(x + Math.floor(w / 2), baseY - h - 4, 1, 4, body);
		else if (roof < 0.46 && w >= 5) g.rect(x + 1, baseY - h - 2, 2, 2, body);
		if (windowSlots) {
			for (let wy = baseY - h + 2; wy < baseY - 1; wy += 3) {
				for (let wx = x + 1; wx < x + w - 1; wx += 2) {
					if (rng() < opts.lit) detail.set(wx, wy, windowSlots[rng() < 0.75 ? 0 : 1]);
				}
			}
			if (opts.neon && rng() < opts.neon && h >= 9 && w >= 6) {
				detail.rect(x + w - 3, baseY - h + 2, 2, 5, rng() < 0.5 ? SLOT.neon1 : SLOT.neon2);
			}
		}
		x += w + (rng() < 0.25 ? 1 : 0);
	}
}

function cloud(g, cx, cy, s, rng) {
	const blobs = [
		[0, 0, 3.2 * s], [-4 * s, 1, 2.4 * s], [4 * s, 1, 2.6 * s], [-1.5 * s, -2 * s, 2.3 * s], [7.5 * s, 2, 1.7 * s], [-7 * s, 2, 1.6 * s],
	];
	for (const [dx, dy, r] of blobs) g.disc(cx + dx, cy + dy + 1, r, SLOT.cloudShade);
	for (const [dx, dy, r] of blobs) g.disc(cx + dx, cy + dy, r - 0.6, SLOT.cloud);
	// flat underside
	const cut = Math.round(cy + 3.2 * s * 0.75);
	for (let y = cut; y < g.h; y++) for (let x = 0; x < g.w; x++) {
		if (Math.abs(x - cx) <= 12 * s && y - cut < 6 && g.get(x, y) >= 0 && (g.get(x, y) === SLOT.cloud || g.get(x, y) === SLOT.cloudShade)) {
			if (y > cut) g.set(x, y, -1);
			else g.set(x, y, SLOT.cloudShade);
		}
	}
}

function bedFlower(g, detail, x, y, petal, tall) {
	for (let i = 0; i < tall; i++) g.set(x, y - i, SLOT.leaf);
	if (tall >= 3) g.set(x + 1, y - 1, SLOT.leaf);
	const fy = y - tall - 1;
	g.set(x, fy - 1, petal);
	g.set(x - 1, fy, petal);
	g.set(x + 1, fy, petal);
	g.set(x, fy + 1, petal);
	detail.set(x, fy, SLOT.lanternGlow);
}

// ---------------------------------------------------------------------------

const WATER_TOP = 26; // rows above the bottom edge
const ORB_X = 147; // moon/sun centre; kept clear of the gap between two columns
const BANK_TOP = 9;

function generate() {
	const rng = mulberry32(20261116);
	const groups = [];

	// Sky: moon/sun, stars and clouds. Anchored to the top centre.
	{
		const G = new Group('sky', 'tc', 260, 78);
		const halo = G.layer();
		const g = G.layer();
		const cx = ORB_X, cy = 31;
		halo.disc(cx, cy, 21, SLOT.halo2);
		halo.disc(cx, cy, 16.5, SLOT.halo1);
		g.disc(cx, cy, 12.4, SLOT.orb);
		for (let i = 0; i < 34; i++) {
			const x = Math.floor(rng() * G.w), y = Math.floor(rng() * 46);
			if (halo.get(x, y) < 0) g.set(x, y, SLOT.star);
		}
		cloud(g, 108, 52, 1.3, rng);
		cloud(g, 181, 66, 1.0, rng);
		cloud(g, 98, 17, 0.8, rng);
		groups.push(G);
	}

	// City: Fuji, skyline, tower, river bank. Anchored to the bottom centre.
	{
		const G = new Group('city', 'bc', 260, 124);
		const far = G.layer();
		const farDetail = G.layer();
		const mid = G.layer();
		const midDetail = G.layer();
		const horizon = G.h - WATER_TOP; // first water row
		const base = horizon - 1;
		const towerX = 151, fujiX = 106;

		fuji(far, fujiX, base, 50, 62);
		skyline(far, farDetail, 0, G.w, base, 5, 17, [SLOT.farCity], [SLOT.farWindow], rng, {
			minW: 5, maxW: 11, lit: 0.1,
			skip: (x, w) => x + w > fujiX - 16 && x < fujiX + 16,
		});
		pagoda(mid, midDetail, 124, base);
		tokyoTower(mid, midDetail, towerX, base, 80);
		skyline(mid, midDetail, 0, G.w, base, 4, 13, [SLOT.nearCity, SLOT.nearCity2], [SLOT.window, SLOT.window2], rng, {
			minW: 6, maxW: 13, lit: 0.3, neon: 0.5,
			skip: (x, w) => (x + w > towerX - 12 && x < towerX + 12) || (x + w > 112 && x < 136),
		});

		// lantern string along the far bank
		const wire = G.layer();
		wire.rect(0, base - 5, G.w, 1, SLOT.wire);
		for (let x = 0; x < G.w; x++) {
			if (x % 16 === 0) wire.rect(x, base - 5, 1, 6, SLOT.wire);
			if (x % 16 === 8 || x % 16 === 3 || x % 16 === 13) {
				wire.rect(x, base - 4, 2, 2, SLOT.lantern);
				wire.set(x, base - 4, SLOT.lanternGlow);
			}
		}

		// river: reflections and ripples
		const water = G.layer();
		for (let i = 0; i < 46; i++) {
			const x = Math.floor(rng() * G.w), y = horizon + 1 + Math.floor(rng() * (WATER_TOP - BANK_TOP - 2));
			water.rect(x, y, 2 + Math.floor(rng() * 6), 1, rng() < 0.55 ? SLOT.waterLight : SLOT.waterDark);
		}
		for (let y = horizon + 1; y < G.h - BANK_TOP - 1; y += 2) {
			const wob = Math.round((rng() - 0.5) * 3);
			water.rect(towerX - 2 + wob, y, 4 + Math.floor(rng() * 3), 1, SLOT.tower);
			water.rect(ORB_X - 2 - wob, y + 1, 3, 1, SLOT.orb);
		}

		// near bank: small trees, grass tufts and a flower bed
		const wood = G.layer();
		const leaves = G.layer();
		const bankY = G.h - BANK_TOP;
		for (let x = 0; x < G.w; x += 3) {
			if (rng() < 0.6) wood.rect(x, bankY - 1, 1 + Math.floor(rng() * 2), 1, SLOT.bankLight);
		}
		const shine = G.layer();
		smallTree(wood, leaves, shine, 92, bankY, 7, 6.5, 'white', rng);
		smallTree(wood, leaves, shine, 118, bankY + 1, 8, 7.5, 'rose', rng);
		smallTree(wood, leaves, shine, 176, bankY, 7, 6.5, 'rose', rng);
		smallTree(wood, leaves, shine, 198, bankY + 1, 9, 7.5, 'white', rng);
		smallTree(wood, leaves, shine, 60, bankY + 1, 8, 7, 'rose', rng);
		const flowers = G.layer();
		const flowerDetail = G.layer();
		const petals = [SLOT.roseLight, SLOT.whiteHi, SLOT.roseMid, SLOT.whiteLight, SLOT.lantern];
		for (let x = 4; x < G.w - 3; x += 8) {
			const fx = x + Math.floor(rng() * 3);
			bedFlower(flowers, flowerDetail, fx, G.h - 1 - Math.floor(rng() * 2), petals[Math.floor(rng() * petals.length)], 2 + Math.floor(rng() * 3));
		}
		groups.push(G);
	}

	// The two big trees: rose on the left, white on the right.
	{
		const G = new Group('roseTree', 'bl', 92, 138);
		bigTree(G, 'rose', {
			x: 18, y: G.h - 1, lean: 0.2, trunk: 46, thick: 8, dir: 1,
			cx: 36, cy: 50, rx: 34, ry: 26, fill: 15, drift: 16,
		}, rng);
		groups.push(G);
	}
	{
		const G = new Group('whiteTree', 'br', 92, 138);
		bigTree(G, 'white', {
			x: G.w - 19, y: G.h - 1, lean: -0.2, trunk: 46, thick: 8, dir: -1,
			cx: G.w - 37, cy: 50, rx: 34, ry: 26, fill: 15, drift: 16,
		}, rng);
		groups.push(G);
	}

	// Boughs hanging in from the top corners.
	{
		const G = new Group('whiteBough', 'tl', 84, 34);
		hangingBranch(G, 'white', 1, rng);
		groups.push(G);
	}
	{
		const G = new Group('roseBough', 'tr', 84, 34);
		hangingBranch(G, 'rose', -1, rng);
		groups.push(G);
	}

	return {
		slots: SLOTS,
		palettes: PALETTES,
		strips: [
			{ fromBottom: WATER_TOP, height: WATER_TOP - BANK_TOP, key: 'water' },
			{ fromBottom: BANK_TOP, height: BANK_TOP, key: 'bank' },
		],
		groups: groups.map((G) => ({ name: G.name, anchor: G.anchor, w: G.w, h: G.h, rects: G.rects(), counts: G.counts })),
	};
}

module.exports = { generate, SLOTS, PALETTES };

if (require.main === module) {
	const scene = generate();
	let total = 0;
	for (const g of scene.groups) {
		total += g.rects.length;
		console.log(g.name.padEnd(12), g.anchor, `${g.w}x${g.h}`, g.rects.length, 'rects', JSON.stringify(g.counts));
	}
	console.log('total', total);
}
