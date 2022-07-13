# Setting Up YCM for Vim

Once YouCompleteMe is in .vim/plugged (or wherever vim plugins are kept)
change `#!/usr/bin/env python` to `#!/usr/bin/env python2` in all *.py files.

** NOTE **
Use the `py3_to_py2.sh` script in scripts/ dir to change all
  `#!/usr/bin/env python` to `#!/usr/bin/env python2`
(automagically) automatically. Doing it manually takes ages.

NOTE: This is done because YCM uses Python2 and is not compatible with Python3.

After this is done run:
  `./install.py --clang-completer (--system-libclang)`

NOTE: use --system-libclang ONLY if you have the latest clang package installed.

NOTE: the following is not necessary if you used `--system-libclang`
Check ~/.vim/plugged/YouCompleteMe/third_party/ycmd for a 'libclang.so' file.
If not found then:
  - cd ~
  - mkdir ycm_build
  - cd ycm_build
  - then use ONE of the following:
    * if using default, without system libclang:
      $ cmake -G "Unix Makefiles" -DPATH_TO_LLVM_ROOT=~/ycm_temp/llvm_root_dir .  ~/.vim/plugged/YouCompleteMe/third_party/ycmd/cpp
    * OR if using system libclang:
      $ cmake -G "Unix Makefiles" -DUSE_SYSTEM_LIBCLANG=ON . ~/.vim/plugged/YouCompleteMe/third_party/ycmd/cpp
    * OR if using custom libclang library:
      $ cmake -G "Unix Makefiles" -DEXTERNAL_LIBCLANG_PATH=/path/to/libclang.so . ~/.vim/plugged/YouCompleteMe/third_party/ycmd/cpp

Then,
  $ ln -s $HOME/dotfiiles/vim/ycm_extra_conf.py $HOME/.ycm_extra_conf.py
