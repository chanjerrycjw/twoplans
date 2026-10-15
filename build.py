#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""把 src/ 下的 css / js / 模板拼成自包含的单文件 HTML。
改完 src/plans.js（数据）后重新跑一次此脚本即可：
    python build.py
"""
import base64
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).parent
SRC = ROOT / 'src'


def read(p):
    return (SRC / p).read_text(encoding='utf-8')


def make_icon(rgb, size=180, ring=(255, 255, 255)):
    """手写一个纯色 + 白色圆环的 PNG，用作 apple-touch-icon。"""
    raw = bytearray()
    cx = cy = (size - 1) / 2
    outer, inner = size * 0.42, size * 0.40
    for y in range(size):
        raw.append(0)  # filter type 0
        for x in range(size):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5
            if inner <= d <= outer:
                raw.extend(ring + (255,))
            else:
                raw.extend(rgb + (255,))

    def chunk(tag, data):
        return (struct.pack('>I', len(data)) + tag + data +
                struct.pack('>I', zlib.crc32(tag + data) & 0xffffffff))

    png = b'\x89PNG\r\n\x1a\n'
    png += chunk(b'IHDR', struct.pack('>IIBBBBB', size, size, 8, 6, 0, 0, 0))
    png += chunk(b'IDAT', zlib.compress(bytes(raw), 9))
    png += chunk(b'IEND', b'')
    return base64.b64encode(png).decode('ascii')


TPL = '''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1,viewport-fit=cover">
<meta name="theme-color" content="{theme}">
<meta name="apple-mobile-web-app-capable" content="yes">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-status-bar-style" content="default">
<meta name="apple-mobile-web-app-title" content="{apptitle}">
<link rel="apple-touch-icon" href="data:image/png;base64,{icon}">
<title>{title}</title>
<style>
{css}
</style>
</head>
<body class="{bodyclass}">
<div class="wrap">
{top}
<main id="app"></main>
<footer>数据存在本机浏览器里，不联网不同步 · 换设备用「导出进度 / 导入进度」搬运</footer>
</div>
<script>
{plans}
{appjs}
</script>
<script>
{boot}
</script>
</body>
</html>
'''

TOPBAR = '''<div class="topbar">
  <a href="../index.html">← 两个计划</a>
  <span class="spacer"></span>
  <a href="{other}">{other_title}</a>
</div>'''


def build():
    css = read('style.css')
    plans = read('plans.js')
    appjs = read('app.js')

    pairs = {'study': 'sing', 'sing': 'study'}
    for pid, other in pairs.items():
        plan_title = None
        # 从 plans.js 里取标题（避免重复维护）
        for line in plans.splitlines():
            if f"id: '{pid}'" in line:
                idx = plans.index(line)
                plan_title = plans.split("title: '", 1)[1].split("'")[0] if idx < 0 else None
                break
        # 更稳妥：直接用 build 时写死的映射（数据文件里第一行 title 紧跟 id）
        block = plans.split(f"id: '{pid}',", 1)[1]
        plan_title = block.split("title: '", 1)[1].split("'", 1)[0]
        other_block = plans.split(f"id: '{other}',", 1)[1]
        other_title = other_block.split("title: '", 1)[1].split("'", 1)[0]

        accent = block.split("accent: '", 1)[1].split("'", 1)[0]
        rgb = tuple(int(accent[i:i + 2], 16) for i in (1, 3, 5))

        top = TOPBAR.replace('{other}', f'{other}.html').replace('{other_title}', f'切到：{other_title}')
        html = TPL.format(
            theme=accent, apptitle=plan_title, icon=make_icon(rgb),
            title=f'{plan_title} · 两个计划', css=css,
            bodyclass='', top=top,
            plans=plans, appjs=appjs,
            boot=f"boot('{pid}', document.getElementById('app'));"
        )
        out = ROOT / f'{pid}.html'
        out.write_text(html, encoding='utf-8')
        print(f'  {out.name:24s} {len(html):>7,} 字符')

    # iOS 合并版
    html = TPL.format(
        theme='#4f46e5', apptitle='两个计划', icon=make_icon((0x4f, 0x46, 0xe5)),
        title='两个计划', css=css, bodyclass='', top='',
        plans=plans, appjs=appjs, boot='bootIOS();'
    )
    out = ROOT / '两个计划-iOS.html'
    out.write_text(html, encoding='utf-8')
    print(f'  {out.name:22s} {len(html):>7,} 字符')


if __name__ == '__main__':
    print('生成单文件页面：')
    build()
