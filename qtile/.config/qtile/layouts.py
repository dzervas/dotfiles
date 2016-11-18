from __future__ import division
from libqtile.layout.tile import Tile

class MasterTile(Tile):
    def cmd_shift(self):
        focused = self.clients.index(self.focused)
        super().shift(focused, self.master - 1)
