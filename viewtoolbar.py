# Copyright (C) 2007, One Laptop Per Child
# Copyright (C) 2009, Tomeu Vizoso
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

from gettext import gettext as _

from gi.repository import Gtk
from gi.repository import GObject

from sugar3.graphics.toolbutton import ToolButton

from browser import Browser


class ViewToolbar(Gtk.Toolbar):
    def __init__(self, activity):
        GObject.GObject.__init__(self)

        self._browser = None

        self._activity = activity
        self._activity.tray.connect('unmap', self.__unmap_cb)
        self._activity.tray.connect('map', self.__map_cb)

        self.zoomout = ToolButton('zoom-out')
        self.zoomout.set_tooltip(_('Zoom out'))
        self.zoomout.connect('clicked', self.__zoomout_clicked_cb)
        self.insert(self.zoomout, -1)
        self.zoomout.show()

        self.zoomin = ToolButton('zoom-in')
        self.zoomin.set_tooltip(_('Zoom in'))
        self.zoomin.connect('clicked', self.__zoomin_clicked_cb)
        self.insert(self.zoomin, -1)
        self.zoomin.show()

        self.separator = Gtk.SeparatorToolItem()
        self.separator.set_draw(True)
        self.insert(self.separator, -1)
        self.separator.show()

        self.fullscreen = ToolButton('view-fullscreen')
        self.fullscreen.set_tooltip(_('Fullscreen'))
        self.fullscreen.connect('clicked', self.__fullscreen_clicked_cb)
        self.insert(self.fullscreen, -1)
        self.fullscreen.show()

        self.traybutton = ToolButton('tray-hide')
        self.traybutton.connect('clicked', self.__tray_clicked_cb)
        self.traybutton.props.sensitive = False
        self.insert(self.traybutton, -1)
        self.traybutton.show()

        tabbed_view = self._activity.get_canvas()

        if tabbed_view.get_n_pages():
            self._connect_to_browser(tabbed_view.props.current_browser)

        tabbed_view.connect_after('switch-page', self.__switch_page_cb)

    def __switch_page_cb(self, tabbed_view, page, page_num):
        self._connect_to_browser(tabbed_view.props.current_browser)

    def _connect_to_browser(self, browser):
        self._browser = browser
        self._update_zoom_buttons()

    def _update_zoom_buttons(self):
        is_webkit_browser = isinstance(self._browser, Browser)
        self.zoomin.set_sensitive(is_webkit_browser)
        self.zoomout.set_sensitive(is_webkit_browser)

    def __zoomin_clicked_cb(self, button):
        tabbed_view = self._activity.get_canvas()
        tabbed_view.props.current_browser.zoom_in()

    def __zoomout_clicked_cb(self, button):
        tabbed_view = self._activity.get_canvas()
        tabbed_view.props.current_browser.zoom_out()

    def __fullscreen_clicked_cb(self, button):
        self._activity.fullscreen()

    def __tray_clicked_cb(self, button):
        if self._activity.tray.props.visible is False:
            self._activity.tray.show()
        else:
            self._activity.tray.hide()

    def __map_cb(self, tray):
        if len(self._activity.tray.get_children()) > 0:
            self.tray_set_hide()

    def __unmap_cb(self, tray):
        if len(self._activity.tray.get_children()) > 0:
            self.tray_set_show()

    def tray_set_show(self):
        self.traybutton.set_icon('tray-show')
        self.traybutton.set_tooltip(_('Show Tray'))

    def tray_set_hide(self):
        self.traybutton.set_icon('tray-hide')
        self.traybutton.set_tooltip(_('Hide Tray'))
