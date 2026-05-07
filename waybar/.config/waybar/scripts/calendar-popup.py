#!/usr/bin/env python3
import gi, signal
gi.require_version('Gtk', '4.0')
gi.require_version('Gtk4LayerShell', '1.0')
from gi.repository import Gtk, Gtk4LayerShell, Gdk

class CalendarPopup(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='waybar.calendar.popup')

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_default_size(280, 280)

        Gtk4LayerShell.init_for_window(win)
        Gtk4LayerShell.set_layer(win, Gtk4LayerShell.Layer.OVERLAY)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.TOP, True)
        Gtk4LayerShell.set_anchor(win, Gtk4LayerShell.Edge.RIGHT, True)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.TOP, 0)
        Gtk4LayerShell.set_margin(win, Gtk4LayerShell.Edge.RIGHT, 60)
        Gtk4LayerShell.set_keyboard_mode(win, Gtk4LayerShell.KeyboardMode.ON_DEMAND)

        css = Gtk.CssProvider()
        css.load_from_string("""
            window {
                background-color: rgba(20, 20, 22, 0.82);
                border-radius: 14px;
                border: 1px solid rgba(255, 255, 255, 0.12);
            }
            calendar {
                background: transparent;
                color: #ffffff;
                font-family: "SF Pro Display", "Helvetica Neue", sans-serif;
                font-size: 14px;
                padding: 12px;
                border: none;
            }
            calendar header {
                color: #ffffff;
                font-weight: 600;
                padding-bottom: 8px;
            }
            calendar header button {
                color: rgba(255, 255, 255, 0.7);
                background: transparent;
                border: none;
                min-height: 24px;
                min-width: 24px;
                border-radius: 50%;
            }
            calendar header button:hover {
                background: rgba(255, 255, 255, 0.1);
                color: #ffffff;
            }
        """)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        calendar = Gtk.Calendar()
        win.set_child(calendar)

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
app = CalendarPopup()
app.run(None)
