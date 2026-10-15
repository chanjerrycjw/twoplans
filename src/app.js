/* 两个计划 · 通用引擎与渲染
 * 纯原生 JS，无依赖。数据全部存在浏览器 localStorage 里。
 */

/* ---------- 日期引擎 ---------- */
function parseYMD(s){const p=s.split('-').map(Number);return new Date(p[0],p[1]-1,p[2]);}
function startOfDay(d){return new Date(d.getFullYear(),d.getMonth(),d.getDate());}
function ymd(d){const p=n=>String(n).padStart(2,'0');return d.getFullYear()+'-'+p(d.getMonth()+1)+'-'+p(d.getDate());}
function diffDays(a,b){return Math.round((startOfDay(b)-startOfDay(a))/86400000);}

function today() { return new Date(); }

function snap(plan){
  const start = parseYMD(START_DATE);
  const now = startOfDay(today());
  const rawDiff = diffDays(start, now) + 1;      // 起算日为第 1 天
  const day = Math.min(Math.max(rawDiff, 1), plan.totalDays);
  const finished = rawDiff > plan.totalDays;
  const week = Math.min(Math.ceil(day / 7), plan.totalWeeks);
  const month = Math.min(Math.ceil(week / 4), 12);
  return { start, day, week, month, finished, todayStr: ymd(now), weekday: now.getDay() };
}

/* ---------- 定位当前模块 ---------- */
function currentBlock(plan, s){
  if(plan.id === 'study'){
    const mi = Math.min(s.month - 1, 11);
    const wi = (s.week - 1) % 4;
    const month = plan.months[mi];
    return { month, block: month.weeks[wi], type: 'week' };
  }
  const mi = Math.min(s.month - 1, 11);
  const month = plan.months[mi];
  let bi = 0;
  if(s.week <= 4) bi = s.week - 1;
  else if(s.week <= 8) bi = 4 + Math.floor((s.week - 5) / 2);
  else if(s.week <= 12) bi = 6 + Math.floor((s.week - 9) / 2);
  else bi = 8 + (Math.min(s.month, 12) - 4);
  bi = Math.min(bi, month.blocks.length - 1);
  return { month, block: month.blocks[bi], type: 'block' };
}

function allItemKeys(plan){
  const keys = [];
  plan.months.forEach(m => {
    const groups = m.weeks || m.blocks || [];
    groups.forEach((g, gi) => {
      (g.items || []).forEach((_, ii) => keys.push(plan.id + ':' + m.m + ':' + gi + ':' + ii));
    });
  });
  if(plan.weekday) plan.weekday.forEach((d, di) => d.items.forEach((_, ii) => keys.push(plan.id + ':wd:' + di + ':' + ii)));
  if(plan.checkpoints) plan.checkpoints.forEach((c, ci) => c.items.forEach((_, ii) => keys.push(plan.id + ':cp:' + ci + ':' + ii)));
  return keys;
}

/* ---------- 存储 ---------- */
const LS_DONE = 'tp:%id:done', LS_IN = 'tp:%id:checkin';
function loadDone(id){ try{ return new Set(JSON.parse(localStorage.getItem(LS_DONE.replace('%id', id)) || '[]')); }catch(e){ return new Set(); } }
function saveDone(id, set){ localStorage.setItem(LS_DONE.replace('%id', id), JSON.stringify([...set])); }
function loadIn(id){ try{ return new Set(JSON.parse(localStorage.getItem(LS_IN.replace('%id', id)) || '[]')); }catch(e){ return new Set(); } }
function saveIn(id, set){ localStorage.setItem(LS_IN.replace('%id', id), JSON.stringify([...set])); }

function streak(set){
  let n = 0;
  const d = startOfDay(today());
  while(set.has(ymd(d))){ n++; d.setDate(d.getDate() - 1); }
  const y = startOfDay(today()); y.setDate(y.getDate() - 1);
  if(n === 0 && set.has(ymd(y))){ while(set.has(ymd(y))){ n++; y.setDate(y.getDate() - 1); } }
  return n;
}

/* ---------- 小工具 ---------- */
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
function pct(a, b){ return b === 0 ? 0 : Math.round(a / b * 100); }

/* ---------- 渲染一个计划 ---------- */
function renderPlan(plan){
  const s = snap(plan);
  const done = loadDone(plan.id);
  const ins = loadIn(plan.id);
  const cur = currentBlock(plan, s);
  const checkedIn = ins.has(s.todayStr);
  const totalItems = allItemKeys(plan).length;

  // 月度完成率
  const monthStat = plan.months.map(m => {
    const groups = m.weeks || m.blocks || [];
    let t = 0, d = 0;
    groups.forEach((g, gi) => (g.items || []).forEach((_, ii) => {
      t++; if(done.has(plan.id + ':' + m.m + ':' + gi + ':' + ii)) d++;
    }));
    return { m: m.m, t, d, p: pct(d, t) };
  });

  const curItems = (cur.block.items || []).map((txt, i) => {
    const key = plan.id + ':' + cur.month.m + ':' +
      ((plan.id === 'study' ? cur.month.weeks : cur.month.blocks).indexOf(cur.block)) + ':' + i;
    return { txt, key, done: done.has(key) };
  });

  // 热力图：最近 8 周（56 天）
  let heat = '';
  const end = startOfDay(today());
  const begin = new Date(end); begin.setDate(begin.getDate() - 55);
  for(let i = 0; i < 56; i++){
    const d = new Date(begin); d.setDate(begin.getDate() + i);
    const k = ymd(d);
    const cls = ['', ins.has(k) ? 'on' : '', k === s.todayStr ? 'today' : ''].filter(Boolean).join(' ');
    heat += '<i class="' + cls + '" title="' + k + '"></i>';
  }

  const wdToday = plan.weekday ? plan.weekday.find(w => w.d === s.weekday) : null;

  const singExtra = plan.id === 'sing' ? `
    <div class="card">
      <h2>今天 · ${esc(wdToday ? wdToday.name : '')}</h2>
      <p class="hint">按星期安排的练习菜单（周一~周日轮转）</p>
      <ul class="checklist">
        ${wdToday ? wdToday.items.map((t, i) => {
          const k = plan.id + ':wd:' + plan.weekday.indexOf(wdToday) + ':' + i;
          return `<li><input type="checkbox" data-key="${k}" ${done.has(k) ? 'checked' : ''}><label>${esc(t)}</label></li>`;
        }).join('') : ''}
      </ul>
    </div>
    <div class="card">
      <h2>曲目推荐</h2>
      <p class="hint">当前在 ${esc(plan.songs[Math.min(s.month - 1, plan.songs.length - 1)].stage)}</p>
      <div class="songs">
        ${plan.songs.map((g, gi) => `
          <div class="song${Math.min(s.month - 1, plan.songs.length - 1) === gi ? ' now' : ''}">
            <div class="st">${esc(g.stage)}</div>
            <ul>${g.list.map(x => '<li>' + esc(x) + '</li>').join('')}</ul>
          </div>`).join('')}
      </div>
    </div>
    <div class="card">
      <h2>月度检查点</h2>
      <p class="hint">每个阶段结束前回头勾一遍，没勾满说明还得练</p>
      <div class="blocks">
        ${plan.checkpoints.map((c, ci) => `
          <div class="mini${Math.min(Math.ceil(s.month / 3), plan.checkpoints.length) - 1 === ci ? ' now' : ''}">
            <b>${esc(c.stage)}</b>
            <ul>${c.items.map((t, i) => {
              const k = plan.id + ':cp:' + ci + ':' + i;
              return `<li style="list-style:none;margin-left:-14px"><label style="display:flex;gap:6px;align-items:flex-start">
                <input type="checkbox" data-key="${k}" ${done.has(k) ? 'checked' : ''} style="margin-top:4px">
                <span>${esc(t)}</span></label></li>`;
            }).join('')}</ul>
          </div>`).join('')}
      </div>
    </div>` : '';

  const html = `
    <div class="hero">
      <h1>${esc(plan.title)}</h1>
      <div class="sub">${esc(plan.sub)} · 起算日 ${START_DATE}</div>
      <div class="hero-grid">
        <div class="stat"><b>${s.day}</b><span>今天是第几天</span></div>
        <div class="stat"><b>${s.week}</b><span>第几周</span></div>
        <div class="stat"><b>${s.month}</b><span>第几月</span></div>
        <div class="stat"><b>${streak(ins)}</b><span>连续打卡（天）</span></div>
      </div>
      <div class="bar"><i style="width:${Math.round(s.day / plan.totalDays * 100)}%"></i></div>
      <div class="barlabel"><span>总进度 ${Math.round(s.day / plan.totalDays * 100)}%（${s.day}/${plan.totalDays} 天）</span>
        <span>任务完成 ${pct(done.size, totalItems)}%</span></div>
    </div>

    <div class="card">
      <h2><span class="badge">第 ${s.month} 月 · ${esc(cur.month.title)}</span></h2>
      <p class="hint" style="margin-top:8px">${esc(cur.block.title)}${cur.block.min ? ' · 建议 ' + esc(cur.block.min) : ''}${cur.block.goal ? ' · ' + esc(cur.block.goal) : ''}</p>
      <ul class="checklist">
        ${curItems.map(i => `<li><input type="checkbox" data-key="${i.key}" ${i.done ? 'checked' : ''}><label>${esc(i.txt)}</label></li>`).join('')}
      </ul>
      <div class="row" style="margin-top:14px">
        <button class="btn ${checkedIn ? 'done' : 'primary'}" data-act="checkin" data-id="${plan.id}">
          ${checkedIn ? '今天已打卡 · 点一下取消' : '今天练完了，打卡'}
        </button>
        <span style="font-size:12px;color:var(--muted)">累计打卡 ${ins.size} 天</span>
      </div>
    </div>

    <div class="card">
      <h2>打卡日历</h2>
      <p class="hint">最近 8 周，橙色框是今天</p>
      <div class="heat">${heat}</div>
      <div class="heat-legend">连续 ${streak(ins)} 天 · 累计 ${ins.size} 天</div>
    </div>

    <div class="card">
      <h2>12 个月地图</h2>
      <p class="hint">当前月高亮，数字为该月的任务完成比例</p>
      <div class="months">
        ${plan.months.map((m, i) => {
          const st = monthStat[i];
          return `<div class="mcard${s.month === m.m ? ' now' : ''}">
            <div class="m-no">第 ${m.m} 月</div>
            <div class="m-title">${esc(m.title)}</div>
            <div class="m-goal">${esc(m.goal || '')}</div>
            <div class="m-pct">${st.d}/${st.t} · ${st.p}%</div>
          </div>`;
        }).join('')}
      </div>
    </div>

    <div class="card">
      <h2>阶段目标</h2>
      <div class="phases">
        ${plan.phases.map(p => `<div class="phase"><b>${esc(p.range)}</b>${esc(p.desc)}</div>`).join('')}
      </div>
    </div>

    ${singExtra}

    <div class="card">
      <h2>全部计划大纲</h2>
      <p class="hint">往下翻能看到整年的内容，勾掉就一直记着</p>
      ${plan.months.map(m => `
        <details style="border-top:1px solid var(--line);padding:10px 0"${s.month === m.m ? ' open' : ''}>
          <summary style="cursor:pointer;font-weight:600">第 ${m.m} 月 · ${esc(m.title)}</summary>
          <div style="margin-top:10px">
            ${(m.weeks || m.blocks || []).map((g, gi) => `
              <div class="mini" style="margin-bottom:10px">
                <b>${esc(g.label || ('Week ' + g.w))} ${esc(g.title)}</b>
                <ul style="list-style:none;padding-left:0;margin-top:6px">
                  ${(g.items || []).map((t, ii) => {
                    const k = plan.id + ':' + m.m + ':' + gi + ':' + ii;
                    return `<li style="display:flex;gap:8px;align-items:flex-start;padding:3px 0">
                      <input type="checkbox" data-key="${k}" ${done.has(k) ? 'checked' : ''} style="margin-top:4px">
                      <span style="font-size:13px">${esc(t)}</span></li>`;
                  }).join('')}
                </ul>
              </div>`).join('')}
          </div>
        </details>`).join('')}
    </div>

    <div class="tools">
      <button class="btn" data-act="export" data-id="${plan.id}">导出进度</button>
      <button class="btn" data-act="import" data-id="${plan.id}">导入进度</button>
      <button class="btn" data-act="reset" data-id="${plan.id}">清空该计划进度</button>
      <input type="file" accept="application/json" style="display:none" data-file="${plan.id}">
    </div>`;
  return html;
}

/* ---------- 事件（全局委托） ---------- */
document.addEventListener('change', e => {
  const el = e.target;
  if(el.matches('input[type=checkbox][data-key]')){
    const id = el.getAttribute('data-key').split(':')[0];
    const set = loadDone(id);
    el.checked ? set.add(el.getAttribute('data-key')) : set.delete(el.getAttribute('data-key'));
    saveDone(id, set);
  }
});

document.addEventListener('click', e => {
  const btn = e.target.closest('[data-act]');
  if(!btn) return;
  const id = btn.getAttribute('data-id');
  const act = btn.getAttribute('data-act');
  if(act === 'checkin'){
    const set = loadIn(id);
    const k = ymd(startOfDay(today()));
    set.has(k) ? set.delete(k) : set.add(k);
    saveIn(id, set);
    location.reload();
  } else if(act === 'reset'){
    if(confirm('确定清空「' + PLANS[id].title + '」的全部勾选和打卡记录？此操作不可恢复。')){
      saveDone(id, new Set()); saveIn(id, new Set()); location.reload();
    }
  } else if(act === 'export'){
    const data = { plan: id, exportedAt: new Date().toISOString(),
      done: [...loadDone(id)], checkin: [...loadIn(id)] };
    const a = document.createElement('a');
    a.href = URL.createObjectURL(new Blob([JSON.stringify(data, null, 2)], {type: 'application/json'}));
    a.download = '两个计划-' + PLANS[id].title + '-进度-' + ymd(new Date()) + '.json';
    a.click();
  } else if(act === 'import'){
    document.querySelector('[data-file="' + id + '"]').click();
  }
});

document.addEventListener('change', e => {
  const el = e.target;
  if(el.matches('input[type=file][data-file]')){
    const id = el.getAttribute('data-file');
    const f = el.files[0]; if(!f) return;
    const r = new FileReader();
    r.onload = () => {
      try{
        const j = JSON.parse(r.result);
        saveDone(id, new Set(j.done || []));
        saveIn(id, new Set(j.checkin || []));
        location.reload();
      }catch(err){ alert('文件格式不对，导入失败。'); }
    };
    r.readAsText(f);
  }
});

/* ---------- 启动 ---------- */
function boot(planId, el){
  const plan = PLANS[planId];
  document.documentElement.style.setProperty('--accent', plan.accent);
  document.documentElement.style.setProperty('--accent-soft', plan.accentSoft);
  document.title = plan.title + ' · 两个计划';
  el.innerHTML = renderPlan(plan);
}

function bootIOS(){
  const order = ['study', 'sing'];
  let active = localStorage.getItem('tp:ios:tab') || 'study';
  document.title = '两个计划';
  document.body.classList.add('ios', 'ios-shell');

  const root = document.getElementById('app');
  root.innerHTML = `
    <div class="ios-title" id="iosTitle"></div>
    <div id="panes"></div>
    <nav class="tabbar">
      ${order.map(id => `<button data-tab="${id}"><span class="dot"></span><span>${PLANS[id].title.slice(0, 6)}</span></button>`).join('')}
    </nav>`;

  function paint(){
    const plan = PLANS[active];
    document.documentElement.style.setProperty('--accent', plan.accent);
    document.documentElement.style.setProperty('--accent-soft', plan.accentSoft);
    document.getElementById('iosTitle').textContent = plan.title;
    document.getElementById('panes').innerHTML = renderPlan(plan);
    document.querySelectorAll('.tabbar button').forEach(b => {
      b.classList.toggle('on', b.getAttribute('data-tab') === active);
    });
    window.scrollTo(0, 0);
  }

  document.querySelector('.tabbar').addEventListener('click', e => {
    const b = e.target.closest('[data-tab]'); if(!b) return;
    // 打卡/导出等按钮点击后 reload 会回到默认 tab，这里把状态写回来
    const cur = active; active = b.getAttribute('data-tab');
    localStorage.setItem('tp:ios:tab', active);
    if(cur !== active) paint();
  });

  // 页面内的「打卡 / 重置 / 导入」会触发 reload，重载后恢复到当前 tab
  const keep = () => localStorage.setItem('tp:ios:tab', active);
  document.addEventListener('click', e => { if(e.target.closest('[data-act]')) keep(); });
  // 勾选也持久化当前 tab
  document.addEventListener('change', e => { if(e.target.matches('input[type=checkbox][data-key]')) keep(); });

  // 勾选后实时刷新百分比（轻量重绘，不整页刷新）
  document.addEventListener('change', e => {
    if(!e.target.matches('input[type=checkbox][data-key]')) return;
    keep();
    const plan = PLANS[active];
    const s = snap(plan);
    const done = loadDone(plan.id);
    const totalItems = allItemKeys(plan).length;
    const lbl = document.querySelector('.barlabel span:last-child');
    if(lbl) lbl.textContent = '任务完成 ' + pct(done.size, totalItems) + '%';
  });

  paint();
}
