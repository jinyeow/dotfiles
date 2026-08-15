if _G.user_config.profile == 'minimal' then
  return
end

local ok, autopairs = pcall(require, 'nvim-autopairs')
if not ok then
  return
end

autopairs.setup({
  check_ts = true,
})
