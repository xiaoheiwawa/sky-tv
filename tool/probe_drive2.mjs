import fs from 'node:fs';
const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sites = cfg.sites || [];
const UA = 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36';
async function get(u) {
  try {
    const r = await fetch(u, { headers: { 'User-Agent': UA } });
    return { status: r.status, text: await r.text() };
  } catch (e) { return { status: 0, text: 'ERR ' + e.message }; }
}
// 1) 多源 play 形态抽样
const drives = sites.filter(s => s.type === 4 && /盘/.test(s.name || '')).slice(1, 7);
for (const s of drives) {
  const sep = s.api.includes('?') ? '&' : '?';
  const home = await get(`${s.api}${sep}filter=1`);
  let json = null; try { json = JSON.parse(home.text); } catch {}
  const list = json && (json.list || json.class && json.list);
  const first = Array.isArray(list) ? list[0] : null;
  if (!first) { console.log(`\n### ${s.name}: 首页无数据 status=${home.status} len=${home.text.length} head=${home.text.slice(0,120)}`); continue; }
  const d = await get(`${s.api}${sep}ac=detail&ids=${encodeURIComponent(first.vod_id)}`);
  let dj = null; try { dj = JSON.parse(d.text); } catch {}
  const dl = dj && (dj.list || dj.data); const item = Array.isArray(dl) ? dl[0] : dl;
  if (!item) { console.log(`\n### ${s.name}: 详情空`); continue; }
  const flags = String(item.vod_play_from || '').split('$$$');
  const groups = String(item.vod_play_url || '').split('$$$');
  console.log(`\n### ${s.name} | flags=[${flags.join(' , ')}] | 集数=${groups.map(g=>g.split('#').length).join('/')}`);
  for (let i = 0; i < Math.min(flags.length, 3); i++) {
    const eps = (groups[i] || '').split('#');
    const last = eps[eps.length - 1] || '';
    const pid = last.split('$').pop();
    if (!pid) continue;
    const p = await get(`${s.api}${sep}play=${encodeURIComponent(pid)}&flag=${encodeURIComponent(flags[i])}`);
    console.log(`  flag=${flags[i]} play -> ${p.text.slice(0, 420)}`);
  }
}