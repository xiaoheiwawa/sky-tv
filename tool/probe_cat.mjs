import fs from 'node:fs';
const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sites = cfg.sites || [];
const UA = 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';
async function get(u) { try { const r = await fetch(u, { headers: { 'User-Agent': UA } }); return { status: r.status, text: await r.text() }; } catch (e) { return { status: 0, text: 'ERR ' + e.message }; } }
const t3 = sites.filter(s => s.type === 3);
console.log('type3 名称:', t3.map(s => `${s.name} | ${s.api.replace('https://mytv.free178.xx.kg/', '')}`).join('\n  '));
const probe = ['TuneHub[B]', '豆瓣[官]', '腾云驾雾', '03影院[优]', '木偶ᶜᵃᵗ丨云盘', '虎牙直播[官]'];
for (const name of probe) {
  const url = `https://mytv.free178.xx.kg/api/${encodeURIComponent(name)}?pwd=dzyyds&filter=1`;
  const r = await get(url);
  const ok = r.status === 200 && /"class"|"list"/.test(r.text);
  console.log(`\n/api/${name} -> ${r.status} ok=${ok} len=${r.text.length} :: ${r.text.slice(0, 150).replace(/\s+/g, ' ')}`);
}