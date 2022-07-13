VIM
---

This is the directory that contains all config related to my Neovim/Vim setup.

The following is a list of the contents of this directory:
* `common/` directory holds the `autoload/` and `plugged/` directories which are
  common for both Neovim and Vim.

* `config.vim` is the aggregrate file that is symlinked to vimrc/init.vim.

* `custom/` directory holds any custom files. e.g. colorschemes

* `projections/` contains templates for Projectionist. My zsh function
  `generate projection FILETYPE` uses these templates to create the necessary
  .projections file in my projects.

* `sources/` directory contains all the defined config files. These include but are
  not limited to functions, plugins, and various configuration settings.
