const fs = require('fs');
const { Resvg } = require('@resvg/resvg-js');

const jobs = [
  { svg: 'assets/logo-icon.svg', png: 'assets/logo-icon.png', width: 512 },
  { svg: 'assets/logo-wordmark.svg', png: 'assets/logo-wordmark.png', width: 1040 },
];

const base = '/Users/einar/projects/multi-agent-skill-sharing/';

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
