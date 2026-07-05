const fs = require('fs');
const path = require('path');
const { Resvg } = require('@resvg/resvg-js');

const jobs = [
  { svg: 'assets/logo-icon.svg', png: 'assets/logo-icon.png', width: 512 },
  { svg: 'assets/logo-wordmark.svg', png: 'assets/logo-wordmark.png', width: 1040 },
  { svg: 'assets/logo-wordmark-dark.svg', png: 'assets/logo-wordmark-dark.png', width: 1040 },
];

// repo root = two levels up from this file (assets/brand-board/render.js)
const base = path.resolve(__dirname, '..', '..') + path.sep;

for (const j of jobs) {
  const svg = fs.readFileSync(base + j.svg, 'utf8');
  const resvg = new Resvg(svg, {
    fitTo: { mode: 'width', value: j.width },
    font: { loadSystemFonts: true },
    background: 'rgba(0,0,0,0)',
  });
  const png = resvg.render().asPng();
  fs.writeFileSync(base + j.png, png);
  console.log('rendered', j.png, png.length, 'bytes');
}
