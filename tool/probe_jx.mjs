import fs from 'node:fs';
const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sites = cfg.sites || [];
const UA = 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';
const s = sites.find(x => x.name === process.argv[3]);
const sep = s.api.includes('?') ? '&' : '?';
async function get(u, hdrs = {}) {
  try { const r = await fetch(u, { headers: { 'User-Agent': UA, ...hdrs } }); return { status: r.status, text: await r.text() }; }
  catch (e) { return { status: 0, text: 'ERR ' + e.message }; }
}
const home = JSON.parse((await get(`${s.api}${sep}filter=1`)).text);
const first = (home.list || [])[0];
const d = JSON.parse((await get(`${s.api}${sep}ac=detail&ids=${encodeURIComponent(first.vod_id)}`)).text);
const item = (d.list || [])[0];
console.log('vod_play_pan:', String(item.vod_play_pan || '').slice(0, 500));
const flags = String(item.vod_play_from).split('$$$');
const groups = String(item.vod_play_url).split('$$$');
const idx = flags.findIndex(f => /优汐#1/.test(f));
const pid = (groups[idx].split('#')[0] || '').split('$').pop();
console.log('\n目标 playId:', pid);
const rules = (cfg.parses || []).slice(0, 6).filter(r => r.type === 1);
for (const r of rules) {
  const u = r.url + encodeURIComponent(pid);
  const res = await get(u);
  const links = [...res.text.matchAll(/https?:[^'"\\\s<>]+?\.(?:m3u8|mp4)[^'"\\\s<>]*/g)].map(m => m[0]).slice(0, 3);
  console.log(`\n--- ${r.name} [${res.status}] len=${res.text.length}`);
  console.log('   head:', res.text.slice(0, 240).replace(/\s+/g, ' '));
  if (links.length) console.log('   links:', links);
}