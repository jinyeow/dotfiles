@echo off
rem zig-cc shim for nvim-treesitter (main) parser compilation on Windows.
rem
rem `tree-sitter build` invokes the C compiler via the Rust `cc` crate, which on a
rem windows-msvc host (1) forces the target triple `x86_64-pc-windows-msvc` and (2) is a
rem single-token CC (so `CC="zig cc"` cannot be used - the `cc` sub-arg is dropped).
rem zig rejects that triple and, for the msvc ABI, would additionally need the Windows SDK.
rem This shim rewrites the triple to zig's bundled-mingw target (x86_64-windows-gnu, needs no
rem SDK) and forwards to `zig cc`, so parsers compile with zig alone - no LLVM/MSVC.
rem
rem treesitter.lua sets CC to this file (Windows only). Requires `zig` on PATH.
set "ARGS=%*"
set "ARGS=%ARGS:x86_64-pc-windows-msvc=x86_64-windows-gnu%"
zig cc %ARGS%
