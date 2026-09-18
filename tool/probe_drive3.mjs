import fs from 'node:fs';
const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sites = cfg.sites || [];
const UA = 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';
const s = sites.find(x => x.name === process.argv[3]) || sites.find(x => x.type === 4 && /盘/.test(x.name||''));
const sep = s.api.includes('?') ? '&' : '?';
async function get(u) { const r = await fetch(u, { headers: { 'User-Agent': UA } }); return { status: r.status, text: await r.text() }; }
const home = await get(`${s.api}${sep}filter=1`);
const json = JSON.parse(home.text);
const first = (json.list || [])[0];
console.log('### 源:', s.name, '| 首项:', JSON.stringify(first).slice(0, 400));
const d = JSON.parse((await get(`${s.api}${sep}ac=detail&ids=${encodeURIComponent(first.vod_id)}`)).text);
const item = (d.list || [])[0] || d.data;
console.log('### 详情 keys:', Object.keys(item).join(','));
console.log('### vod_play_from:', item.vod_play_from);
const flags = String(item.vod_play_from||'').split('$$$');
const groups = String(item.vod_play_url||'').split('$$$');
for (let i = 0; i < flags.length; i++) {
  const eps = (groups[i]||'').split('#');
  const pid = (eps[0]||'').split('$').pop();
  const p = await get(`${s.api}${sep}play=${encodeURIComponent(pid)}&flag=${encodeURIComponent(flags[i])}`);
  console.log(`\n[${flags[i]}] playId=${pid}\n  FULL: ${p.text.slice(0, 900)}`);
}
console.log('\n### parses(head):', JSON.stringify((cfg.parses||[]).slice(0,5)).slice(0, 700));
console.log('### spider:', JSON.stringify(cfg.spider));