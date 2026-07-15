if _G.user_config.profile == 'minimal' then
  return
end

local ok, orgmode = pcall(require, 'orgmode')
if not ok then
  return
end

-- setup() compiles the bundled tree-sitter-org grammar on first run (zig is the
-- fallback compiler, and the last candidate tried — see plugins.lua).
orgmode.setup({
  org_agenda_files = '~/org/**/*',
  org_default_notes_file = '~/org/inbox.org',
  org_todo_keywords = { 'TODO', 'NEXT', 'WAIT', '|', 'DONE' },
  org_log_done = 'time',
  org_capture_templates = {
    t = {
      description = 'Task',
      template = '* TODO %?\n  %u',
    },
    -- Each %^{...} prompt must appear exactly once: every occurrence is queued as
    -- a separate prompt, but the first answer substitutes all of them — so a
    -- repeated token asks twice and silently discards the second answer.
    p = {
      description = 'PBI',
      target = '~/org/work.org',
      headline = 'PBIs',
      template = {
        '* TODO [%^{PBI id}] %^{Title}',
        '  %u',
        '  %?',
        '** TODO Read acceptance criteria',
        '** TODO Implement',
        '** TODO PR + review',
      },
    },
    j = {
      description = 'Journal',
      target = '~/org/journal.org',
      datetree = true,
      template = '* %<%H:%M> %?',
    },
  },
})
