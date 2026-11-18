# dmgbuild settings for the Civa disk image. scripts/release.sh passes `app`, `icon`, and `background`
# as defines (dmgbuild runs this file without __file__).
import os.path

app = defines["app"]

format = "UDZO"
files = [app]
symlinks = {"Applications": "/Applications"}
icon = defines["icon"]
background = defines["background"]

# Matches background.tiff: a 660 × 440 pt window, icons centered on the arrow's two ends.
window_rect = ((200, 120), (660, 440))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
icon_size = 128
text_size = 13
icon_locations = {
    os.path.basename(app): (165, 118),
    "Applications": (495, 118),
}
