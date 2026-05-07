#!/usr/bin/env python3
import gi, signal
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gtk4LayerShell, Gdk, Pango
import subprocess
import os

def get_cpu_info():
    model = "Unknown"
    with open('/proc/cpuinfo') as f:
        for line in f:
            if 'model name' in line:
                model = line.split(':')[1].strip()
                break
    cores = os.cpu_count()
    with open('/proc/stat') as f:
        parts = f.readline().split()
        user, nice, system, idle = int(parts[1]), int(parts[2]), int(parts[3]), int(parts[4])
        usage = int((user + nice + system) * 100 / (user + nice + system + idle))
    try:
        with open('/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq') as f:
            freq = f"{int(f.read().strip()) // 1000} MHz"
    except:
        freq = "N/A"
    with open('/proc/loadavg') as f:
        load = ' '.join(f.read().split()[:3])
    result = subprocess.run(['ps', '-eo', 'pcpu,comm', '--sort=-pcpu'], capture_output=True, text=True)
    top = result.stdout.strip().split('\n')[1:6]
    return model, cores, usage, freq, load, top


class CpuPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='waybar.cpuinfo.popup')

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_default_size(320, -1)

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 0)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.RIGHT, 160)
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.ON_DEMAND)

        css = Gtk.CssProvider()
        css.load_from_string("""
            window {
                background-color: rgba(20, 20, 22, 0.82);
                border-radius: 14px;
                border: 1px solid rgba(255, 255, 255, 0.12);
            }
            box {
                padding: 16px;
            }
            .title {
                color: #ffffff;
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 15px;
                font-weight: 700;
            }
            .model {
                color: rgba(255, 255, 255, 0.5);
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 12px;
            }
            .stat {
                color: #ffffff;
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 13px;
            }
            .stat-label {
                color: rgba(255, 255, 255, 0.5);
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 13px;
            }
            .section-title {
                color: rgba(255, 255, 255, 0.5);
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 11px;
                font-weight: 600;
            }
            .process {
                color: #ffffff;
                font-family: "SF Mono", "JetBrains Mono", monospace;
                font-size: 12px;
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        model, cores, usage, freq, load, top_procs = get_cpu_info()

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)

        title = Gtk.Label(label="CPU")
        title.set_halign(Gtk.Align.START)
        title.add_css_class("title")
        box.append(title)

        model_label = Gtk.Label(label=model)
        model_label.set_halign(Gtk.Align.START)
        model_label.set_ellipsize(Pango.EllipsizeMode.END)
        model_label.add_css_class("model")
        box.append(model_label)

        box.append(Gtk.Separator())

        stats = [
            ("Cores", str(cores)),
            ("Usage", f"{usage}%"),
            ("Frequency", freq),
            ("Load Average", load),
        ]
        for label_text, value_text in stats:
            row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
            lbl = Gtk.Label(label=label_text)
            lbl.set_halign(Gtk.Align.START)
            lbl.set_hexpand(True)
            lbl.add_css_class("stat-label")
            val = Gtk.Label(label=value_text)
            val.set_halign(Gtk.Align.END)
            val.add_css_class("stat")
            row.append(lbl)
            row.append(val)
            box.append(row)

        box.append(Gtk.Separator())

        section = Gtk.Label(label="TOP PROCESSES")
        section.set_halign(Gtk.Align.START)
        section.add_css_class("section-title")
        box.append(section)

        for proc in top_procs:
            parts = proc.strip().split(None, 1)
            if len(parts) == 2:
                proc_label = Gtk.Label(label=f"{parts[1]:<20} {parts[0]:>6}%")
                proc_label.set_halign(Gtk.Align.START)
                proc_label.add_css_class("process")
                box.append(proc_label)

        win.set_child(box)

        # Close on Escape
        key = Gtk.EventControllerKey()
        key.connect('key-pressed', self._on_key)
        win.add_controller(key)

        # Close when window loses focus (click away)
        win.connect('notify::is-active', self._on_active_changed)

        win.present()

    def _on_active_changed(self, win, pspec):
        if not win.get_property('is-active'):
            self.quit()

    def _on_key(self, controller, keyval, keycode, state):
        if keyval == Gdk.KEY_Escape:
            self.quit()
            return True
        return False

signal.signal(signal.SIGTERM, lambda *_: exit(0))
app = CpuPopup()
app.run(None)
