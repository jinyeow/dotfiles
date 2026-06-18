-- git.yazi: show Git file status as a linemode in the file list.
-- Fetchers are registered in yazi.toml ([plugin].prepend_fetchers).
require("git"):setup {
  order = 1500,
}
