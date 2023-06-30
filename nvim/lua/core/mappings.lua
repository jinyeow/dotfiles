require("core.functions")

local g = vim.g
local keymap = vim.keymap

g.mapleader = ' '
g.maplocalleader = '\\'

keymap.set("n", "-", vim.cmd.Ex)

map("n", "<bs>", ":nohlsearch<cr>", { silent = true })
map("n", "<leader>n", ":bnext<cr>", { silent = true })
map("n", "<leader>p", ":bprev<cr>", { silent = true })
