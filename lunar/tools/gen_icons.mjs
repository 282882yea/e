// Rasterises the icon sheet used by Lunar (white strokes on transparent, tinted at runtime).
//
//   npm i lucide-static playwright   (any location on NODE_PATH)
//   node gen_icons.mjs               -> ../assets/icons.png + ../assets/icons.json
//
// Icons come from Lucide (ISC licence, https://lucide.dev) plus two custom glyphs.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

const require = createRequire(import.meta.url)
const here = path.dirname(fileURLToPath(import.meta.url))
const out = path.join(here, '..', 'assets')
const lucideDir = path.dirname(require.resolve('lucide-static/package.json'))
const { chromium } = require('playwright')

const CELL = 48
const COLS = 8

const custom = {
    wave: '<path d="M3 12C5.5 4.5 8.5 4.5 12 12s6.5 7.5 9 0"/>',
    grip: '<path d="M21.5 5 5 21.5M21.5 10.5 10.5 21.5M21.5 16 16 21.5M21.5 21 21 21.5" stroke-width="1.3"/>',
}

const names = [
    'moon', 'locate-fixed', 'circle-dot', 'eye', 'zap', 'user', 'settings', 'search',
    'chevron-down', 'ellipsis', 'timer', 'box', 'command', 'check', 'x', 'wave',
    'grip', 'crosshair', 'target', 'shield', 'sliders-horizontal', 'palette', 'keyboard', 'sparkles',
    'rotate-ccw', 'chevrons-up-down', 'minus', 'plus', 'activity', 'info', 'bell', 'save',
    'folder', 'trash-2', 'gauge', 'move', 'wind', 'layers', 'globe', 'lock',
    'mouse-pointer-click', 'scan', 'radar', 'flower-2', 'star', 'heart', 'power', 'chevron-right',
    'swords', 'sword', 'layout-grid', 'venetian-mask', 'ghost', 'flame', 'volume-2', 'camera',
    'package', 'bug', 'folder-cog', 'sun', 'cloud', 'cloud-rain', 'cloud-lightning', 'music',
    'image', 'monitor', 'footprints', 'trophy', 'gift', 'user-cog', 'users', 'list',
    'file-text', 'clipboard', 'copy', 'refresh-cw', 'code', 'skull', 'bomb', 'shirt',
    'award', 'wrench', 'droplet', 'mountain', 'aperture', 'video', 'type', 'pipette',
    'paintbrush', 'hand', 'wand-sparkles', 'map-pin', 'eye-off', 'scan-eye', 'crown', 'history',
]

function inner(name) {
    if (custom[name]) return custom[name]
    const file = path.join(lucideDir, 'icons', name + '.svg')
    const svg = fs.readFileSync(file, 'utf8')
    return svg.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '')
}

const rows = Math.ceil(names.length / COLS)
const cells = names.map((n, i) => {
    const x = (i % COLS) * CELL, y = Math.floor(i / COLS) * CELL
    return `<svg x="${x}" y="${y}" width="${CELL}" height="${CELL}" viewBox="0 0 24 24" fill="none" stroke="#fff" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">${inner(n)}</svg>`
})
const sheet = `<svg xmlns="http://www.w3.org/2000/svg" width="${COLS * CELL}" height="${rows * CELL}">${cells.join('')}</svg>`

const browser = await chromium.launch()
const page = await browser.newPage({ viewport: { width: COLS * CELL, height: rows * CELL }, deviceScaleFactor: 1 })
await page.setContent(`<body style="margin:0;background:transparent">${sheet}</body>`)
await page.screenshot({ path: path.join(out, 'icons.png'), omitBackground: true })
await browser.close()

const map = {}
names.forEach((n, i) => { map[n] = [(i % COLS) * CELL, Math.floor(i / COLS) * CELL] })
fs.writeFileSync(path.join(out, 'icons.json'), JSON.stringify({ cell: CELL, icons: map }, null, 1))
console.log('icons:', names.length, fs.statSync(path.join(out, 'icons.png')).size, 'bytes')
