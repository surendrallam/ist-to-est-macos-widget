#!/usr/bin/env python3
"""Generates design/AppIcon.svg and docs/favicon.svg.

The two clocks show the same instant: 10:10 in India (front, day face) and
00:40 in New York during EDT (back, night face).
"""
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def hand(cx, cy, angle_deg, length, width, color, tail=0.0):
    a = math.radians(angle_deg)
    x2, y2 = cx + length * math.sin(a), cy - length * math.cos(a)
    x1, y1 = cx - tail * math.sin(a), cy + tail * math.cos(a)
    return (f'<line x1="{x1:.1f}" y1="{y1:.1f}" x2="{x2:.1f}" y2="{y2:.1f}" '
            f'stroke="{color}" stroke-width="{width}" stroke-linecap="round"/>')


def clock(cx, cy, r, face, ink, hour, minute, ring):
    parts = [
        f'<circle cx="{cx}" cy="{cy}" r="{r + ring}" fill="url(#ring)"/>',
        f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{face}"/>',
    ]
    for i in range(12):
        a = math.radians(i * 30)
        major = i % 3 == 0
        outer, inner = r * 0.88, r * (0.70 if major else 0.77)
        parts.append(
            f'<line x1="{cx + inner * math.sin(a):.1f}" y1="{cy - inner * math.cos(a):.1f}" '
            f'x2="{cx + outer * math.sin(a):.1f}" y2="{cy - outer * math.cos(a):.1f}" '
            f'stroke="{ink}" stroke-opacity="{0.9 if major else 0.45}" '
            f'stroke-width="{r * (0.055 if major else 0.035):.1f}" stroke-linecap="round"/>')
    parts.append(hand(cx, cy, (hour % 12 + minute / 60) * 30, r * 0.52, r * 0.11, ink, r * 0.08))
    parts.append(hand(cx, cy, minute * 6, r * 0.76, r * 0.075, ink, r * 0.08))
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.09:.1f}" fill="#FF8A1F"/>')
    parts.append(f'<circle cx="{cx}" cy="{cy}" r="{r * 0.035:.1f}" fill="{face}"/>')
    return "\n    ".join(parts)


def app_icon():
    back = clock(626, 618, 196, "#17153A", "#FFFFFF", 0, 40, 18)
    front = clock(418, 420, 226, "#FFFFFF", "#1C1C1E", 10, 10, 22)
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFB547"/>
      <stop offset="0.5" stop-color="#F2545B"/>
      <stop offset="1" stop-color="#3D2FB5"/>
    </linearGradient>
    <linearGradient id="ring" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.55"/>
      <stop offset="1" stop-color="#FFFFFF" stop-opacity="0.15"/>
    </linearGradient>
    <filter id="shadow" x="-10%" y="-10%" width="120%" height="125%">
      <feDropShadow dx="0" dy="12" stdDeviation="14" flood-color="#000" flood-opacity="0.3"/>
    </filter>
    <filter id="soft" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="10" stdDeviation="16" flood-color="#000" flood-opacity="0.28"/>
    </filter>
    <clipPath id="squircle"><rect x="100" y="100" width="824" height="824" rx="185"/></clipPath>
  </defs>
  <g filter="url(#shadow)">
    <rect x="100" y="100" width="824" height="824" rx="185" fill="url(#bg)"/>
  </g>
  <g clip-path="url(#squircle)">
    <g filter="url(#soft)">
    {back}
    </g>
    <g filter="url(#soft)">
    {front}
    </g>
  </g>
</svg>
'''


def favicon():
    front = clock(30, 30, 24, "#FFFFFF", "#1C1C1E", 10, 10, 0).replace('fill="url(#ring)"', 'fill="none"')
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="64" height="64" viewBox="0 0 64 64">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#FFB547"/>
      <stop offset="0.5" stop-color="#F2545B"/>
      <stop offset="1" stop-color="#3D2FB5"/>
    </linearGradient>
  </defs>
  <rect width="64" height="64" rx="14" fill="url(#bg)"/>
  <g transform="translate(2 2)">
    {front}
  </g>
</svg>
'''


if __name__ == "__main__":
    (ROOT / "design").mkdir(exist_ok=True)
    (ROOT / "design" / "AppIcon.svg").write_text(app_icon())
    (ROOT / "docs").mkdir(exist_ok=True)
    (ROOT / "docs" / "favicon.svg").write_text(favicon())
    print("wrote design/AppIcon.svg and docs/favicon.svg")
