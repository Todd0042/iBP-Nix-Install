#!/usr/bin/env python3
"""iBP keybind overlay — i3 edition.

Two ways to learn i3's bind table:
  (a) parse ~/.config/i3/config directly
  (b) `i3-msg -t get_bindings -- get_config` (newer i3 only)

(a) is more portable AND survives i3 not being able to reload mid-edit, so
we use that. We watch the mtime so live edits update the overlay within
REFRESH_MS.
"""

import os
import re
import shutil
import signal
import subprocess
import sys
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QTimer
    from PySide6.QtGui import QColor, QPainter, QBrush
    from PySide6.QtWidgets import (
        QApplication, QWidget, QVBoxLayout, QLabel, QScrollArea, QFrame
    )
except ImportError:
    sys.stderr.write("PySide6 missing. Install via pkgs.python3Packages.pyside6.\n")
    sys.exit(1)

CONFIG     = Path.home() / ".config" / "i3" / "config"
REFRESH_MS = 2500
TARGET_OUTPUT = "DP-3"

VAR_LINE   = re.compile(r"^\s*set\s+(\$\w+)\s+(.+?)\s*$")
BIND_LINE  = re.compile(r"^\s*bindsym\s+(\S+)\s+(.+?)\s*$")
MODE_OPEN  = re.compile(r'^\s*mode\s+"([^"]+)"\s*\{?\s*$')
MODE_CLOSE = re.compile(r'^\s*\}\s*$')


def expand(s, vars):
    # iterate until stable so $browser referring to $term works too
    for _ in range(5):
        prev = s
        for k, v in vars.items():
            s = s.replace(k, v)
        if s == prev:
            break
    return s


def fetch_binds():
    if not CONFIG.exists():
        return [], 0
    vars = {}
    binds = []   # list of (combo, action, mode_or_None)
    cur_mode = None
    try:
        text = CONFIG.read_text()
    except OSError as exc:
        return [("(read error)", str(exc), None)], 0

    for line in text.splitlines():
        s = line.strip()
        if not s or s.startswith("#"):
            continue
        m = VAR_LINE.match(line)
        if m:
            vars[m.group(1)] = m.group(2)
            continue
        m = MODE_OPEN.match(line)
        if m:
            cur_mode = m.group(1)
            continue
        if cur_mode and MODE_CLOSE.match(line):
            cur_mode = None
            continue
        m = BIND_LINE.match(line)
        if m:
            keys = expand(m.group(1), vars)
            action = expand(m.group(2), vars).strip()
            # strip exec --no-startup-id, exec, quoted args for readability
            action = re.sub(r"^exec(?:\s+--no-startup-id)?\s+", "", action)
            action = action.strip().strip('"').strip()
            binds.append((keys, action, cur_mode))
    return binds, CONFIG.stat().st_mtime


class Overlay(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowFlags(
            Qt.FramelessWindowHint
          | Qt.WindowStaysOnTopHint
          | Qt.Tool
          | Qt.X11BypassWindowManagerHint
          | Qt.WindowDoesNotAcceptFocus
        )
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setWindowOpacity(0.88)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(14, 12, 14, 12)
        outer.setSpacing(6)

        self.title = QLabel("Keybinds — i3")
        self.title.setStyleSheet(
            "color:#88c0d0;font-weight:700;font-size:13px;font-family:'JetBrainsMono Nerd Font';"
        )
        outer.addWidget(self.title)

        rule = QFrame(); rule.setFrameShape(QFrame.HLine)
        rule.setStyleSheet("color:#4c566a;")
        outer.addWidget(rule)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setStyleSheet("background:transparent;")
        outer.addWidget(scroll, 1)
        inner = QWidget(); inner.setStyleSheet("background:transparent;")
        scroll.setWidget(inner)
        il = QVBoxLayout(inner); il.setContentsMargins(0,0,0,0); il.setSpacing(2)

        self.body = QLabel("")
        self.body.setStyleSheet(
            "color:#eceff4;font-family:'JetBrainsMono Nerd Font',monospace;font-size:10pt;"
        )
        self.body.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        self.body.setWordWrap(True)
        self.body.setTextFormat(Qt.RichText)
        il.addWidget(self.body, 1)

        self.foot = QLabel("Super+F1 toggle · live-reads ~/.config/i3/config")
        self.foot.setStyleSheet("color:#4c566a;font-size:9pt;")
        outer.addWidget(self.foot)

        self.last_mtime = 0
        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(REFRESH_MS)
        self.refresh()

    def refresh(self):
        binds, mtime = fetch_binds()
        if mtime == self.last_mtime and self.body.text():
            return
        self.last_mtime = mtime
        if not binds:
            self.body.setText("<i>no binds found in config</i>")
            return
        # group by mode (None first = default, then named modes)
        default = [b for b in binds if b[2] is None]
        modes   = {}
        for b in binds:
            if b[2] is not None:
                modes.setdefault(b[2], []).append(b)

        maxlen = max((len(k) for k, _, _ in binds), default=0)

        def fmt(rows):
            out = []
            for combo, action, _ in rows:
                pad = " " * (maxlen - len(combo) + 2)
                out.append(
                    "<span style='color:#a3be8c;'>{0}</span>"
                    "<span style='color:#4c566a;white-space:pre;'>{1}</span>"
                    "<span style='color:#d8dee9;'>→ {2}</span>"
                    .format(combo, pad, action)
                )
            return "<br>".join(out)

        chunks = [fmt(default)]
        for name, rows in modes.items():
            chunks.append("<br><b style='color:#ebcb8b;'>mode: {}</b>".format(name))
            chunks.append(fmt(rows))
        self.body.setText("<br>".join(chunks))

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setBrush(QBrush(QColor(46, 52, 64, 215)))
        p.setPen(Qt.NoPen)
        p.drawRoundedRect(self.rect(), 10, 10)

    def toggle(self):
        self.setVisible(not self.isVisible())


def position_on_left_monitor(app, w):
    target = None
    for s in app.screens():
        if s.name() == TARGET_OUTPUT:
            target = s; break
    if target is None:
        target = sorted(app.screens(), key=lambda s: s.geometry().x())[0]
    g = target.geometry()
    w.move(g.x() + g.width() - w.width() - 18,
           g.y() + g.height() - w.height() - 32)


def main():
    app = QApplication(sys.argv)
    w = Overlay()
    w.resize(420, 640)
    position_on_left_monitor(app, w)
    w.show()

    signal.signal(signal.SIGUSR1, lambda *a: w.toggle())
    signal.signal(signal.SIGUSR2, lambda *a: w.refresh())
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
