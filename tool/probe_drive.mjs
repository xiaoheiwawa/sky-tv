import fs from 'node:fs';

const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const sites = cfg.sites || [];
const targets = sites.filter(s => /盘/.test(s.name || ''));
console.log('候选网盘源数量:', targets.length);
for (const s of targets.slice(0, 6)) {
  console.log('---', s.name, '| type', s.type, '| api', s.api, '| ext', (s.ext || '').slice(0, 60), '| searchable', s.searchable, '| quickSearch', s.quickSearch);
}
const target = targets.find(s => /木偶/.test(s.name)) || targets[0];
if (!target) process.exit(0);
console.log('\n=== 选中:', target.name, target.api);
const sep = target.api.includes('?') ? '&' : '?';
const url = (q) => `${target.api}${sep}${q}`;
async function get(u) {
  const t0 = Date.now();
  try {
    const r = await fetch(u, { headers: { 'User-Agent': 'Mozilla/5.0 (Linux; Android 9) AppleWebKit/537.36 Chrome/120 Mobile Safari/537.36' } });
    const text = await r.text();
    console.log(`\n<<< ${r.status} ${Date.now() - t0}ms len=${text.length} ${u.slice(0, 160)}`);
    return { status: r.status, text };
  } catch (e) {
    console.log(`\n<<< ERROR ${Date.now() - t0}ms ${u.slice(0, 160)} :: ${e.message}`);
    return { status: 0, text: '' };
  }
}
const home = await get(url('filter=1'));
console.log(home.text.slice(0, 3000));
let json = null;
try { json = JSON.parse(home.text); } catch {}
const list = json && (json.list || json.data || json.result);
if (Array.isArray(list) && list.length) {
  const first = list[0];
  console.log('\n首页首项:', JSON.stringify(first).slice(0, 1200));
  const id = first.vod_id || first.id;
  const d = await get(url(`ac=detail&ids=${encodeURIComponent(id)}`));
  console.log(d.text.slice(0, 4000));
  let dj = null;
  try { dj = JSON.parse(d.text); } catch {}
  const dlist = dj && (dj.list || dj.data);
  const item = Array.isArray(dlist) ? dlist[0] : dlist;
  if (item) {
    for (const k of ['vod_play_url', 'vod_play_from', 'vod_play_server']) {
      if (item[k]) console.log(`\n${k} =`, String(item[k]).slice(0, 800));
    }
    const playUrl = String(item.vod_play_url || '').split('#')[0];
    const flag = String(item.vod_play_from || '').split('$$$')[0];
    const playId = playUrl.split('$').pop();
    console.log('\n-> play id:', playId, '| flag:', flag);
    if (playId) {
      const p = await get(url(`play=${encodeURIComponent(playId)}&flag=${encodeURIComponent(flag)}`));
      console.log(p.text.slice(0, 3000));
    }
  }
}