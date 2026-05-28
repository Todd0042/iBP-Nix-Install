#!/usr/bin/env python3
"""iBP keybind overlay — Hyprland edition.

Reads the running compositor's bind table every REFRESH_MS and shows it as
an always-on-top, semi-transparent panel pinned to the lower-right of the
*left* monitor (DP-3 in our 4-monitor layout).

Why query `hyprctl binds -j` instead of parsing keybinds.conf?
  Because Hyprland evaluates source-includes, $variables, and bind/binde/
  bindl/bindel/bindm subtleties at runtime. The compositor's own table is
  the only ground truth. Any edit you make + `hyprctl reload` is picked up
  here automatically.

Signals:
  SIGUSR1 → toggle visibility (used by Super+F1 in keybinds.conf)
  SIGUSR2 → force refresh
"""

import json
import os
import shutil
import signal
import subprocess
import sys
from pathlib import Path

try:
    from PySide6.QtCore import Qt, QTimer, Signal
    from PySide6.QtGui  import QColor, QPainter, QBrush, QFont
    from PySide6.QtWidgets import (
        QApplication, QWidget, QVBoxLayout, QLabel, QScrollArea, QFrame
    )
except ImportError:
    sys.stderr.write("PySide6 missing. Install via pkgs.python3Packages.pyside6.\n")
    sys.exit(1)

REFRESH_MS = 2500
TARGET_OUTPUT = "DP-3"   # leftmost monitor in our layout

# Hyprland modmask bit table (from libxkbcommon — what `hyprctl binds -j` emits)
MOD_NAMES = [
    (64, "Super"),
    ( 4, "Ctrl"),
    ( 8, "Alt"),
    ( 1, "Shift"),
]

def fetch_binds():
    """Return [(combo_str, action_str), ...] sorted by mod-order."""
    if not shutil.which("hyprctl"):
        return [("(hyprctl missing)", "")]
    try:
        raw = subprocess.check_output(
            ["hyprctl", "binds", "-j"], text=True, timeout=2)
    except Exception as exc:
        return [("(hyprctl error)", str(exc))]
    try:
        items = json.loads(raw)
    except json.JSONDecodeError:
        return [("(json parse error)", "")]

    out = []
    for b in items:
        mods = b.get("modmask", 0) or 0
        key  = b.get("key", "") or ""
        parts = [name for bit, name in MOD_NAMES if mods & bit]
        if key:
            parts.append(key)
        combo = "+".join(parts) if parts else "(no key)"
        action = "{} {}".format(b.get("dispatcher", ""), b.get("arg", "")).strip()
        if not action:
            action = "(noop)"
        out.append((combo, action))
    return out


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

        self.title = QLabel("Keybinds — Hyprland")
        self.title.setStyleSheet(
            "color:#88c0d0;font-weight:700;font-size:13px;font-family:'JetBrainsMono Nerd Font';"
        )
        outer.addWidget(self.title)

        rule = QFrame()
        rule.setFrameShape(QFrame.HLine)
        rule.setStyleSheet("color:#4c566a;")
        outer.addWidget(rule)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setStyleSheet("background:transparent;")
        outer.addWidget(scroll, 1)

        inner = QWidget()
        scroll.setWidget(inner)
        self._inner_layout = QVBoxLayout(inner)
        self._inner_layout.setContentsMargins(0, 0, 0, 0)
        self._inner_layout.setSpacing(2)
        inner.setStyleSheet("background:transparent;")

        self.body = QLabel("")
        self.body.setStyleSheet(
            "color:#eceff4;font-family:'JetBrainsMono Nerd Font',monospace;font-size:10pt;"
        )
        self.body.setAlignment(Qt.AlignTop | Qt.AlignLeft)
        self.body.setWordWrap(True)
        self.body.setTextFormat(Qt.RichText)
        self._inner_layout.addWidget(self.body, 1)

        self.foot = QLabel("Super+F1 toggle · live-reads `hyprctl binds`")
        self.foot.setStyleSheet("color:#4c566a;font-size:9pt;")
        outer.addWidget(self.foot)

        self.timer = QTimer(self)
        self.timer.timeout.connect(self.refresh)
        self.timer.start(REFRESH_MS)
        self.refresh()

    def refresh(self):
        binds = fetch_binds()
        if not binds:
            self.body.setText("<i>no binds reported</i>")
            return
        # Build a 2-column-ish table with mono key column
        rows = []
        # Column-align the key column. Find longest combo string.
        maxlen = max((len(k) for k, _ in binds), default=0)
        for combo, action in binds:
            pad = " " * (maxlen - len(combo) + 2)
            rows.append(
                "<span style='color:#a3be8c;'>{0}</span>"
                "<span style='color:#4c566a;white-space:pre;'>{1}</span>"
                "<span style='color:#d8dee9;'>→ {2}</span>"
                .format(combo, pad, action)
            )
        self.body.setText("<br>".join(rows))

    def paintEvent(self, _):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)
        p.setBrush(QBrush(QColor(46, 52, 64, 215)))   # #2E3440 @ 215 alpha
        p.setPen(Qt.NoPen)
        p.drawRoundedRect(self.rect(), 10, 10)

    def toggle(self):
        self.setVisible(not self.isVisible())


def position_on_left_monitor(app, w):
    """Place the overlay on the bottom-right corner of DP-3 (our left mon)."""
    target = None
    for s in app.screens():
        if s.name() == TARGET_OUTPUT:
            target = s
            break
    if target is None:
        # Fallback: pick the leftmost screen by geometry.x()
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

    # SIGUSR1 = toggle, SIGUSR2 = force refresh
    def on_usr1(_sig, _frame): w.toggle()
    def on_usr2(_sig, _frame): w.refresh()
    signal.signal(signal.SIGUSR1, on_usr1)
    signal.signal(signal.SIGUSR2, on_usr2)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
