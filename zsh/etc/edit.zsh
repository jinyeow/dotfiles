# Edit Functions and Helper Functions

# Quickly open a particular thing to edit.
edit () {
  case $1 in
    conf|config*)
      edit_config $2
      ;;
    proj|projection*)
      edit_projection $2
      ;;
    motd)
      motd edit
      ;;
    script*)
      $EDITOR "$HOME/scripts/$2"
      ;;
    stor*)
      shift 1
      edit_story $@
      ;;
    zsh)
      shift 1
      edit_zsh $@
      ;;
    new)
      shift 1
      edit_new $@
      ;;
    note*)
      shift 1
      edit_notes $@
      ;;
    -l|list)
      echo "Editable:"
      printf "  - configs\n  - projections\n  - scripts\n  - stories\n  - zsh\n"
      ;;
    -h|help)
      echo "Usage: $0 [editable] [arguments]"
      echo "Editable things:"
      echo "  configs:    Edit various config files."
      echo "  projection: Edit {filetype}_projections.json files."
      echo "  scripts:    Edit various scripts."
      echo "  stories:    Edit story project."
      echo "  zsh:        Edit zsh configs, modules, and miscellaneous items."
      ;;
    *)
      echo "$1 is not a valid edit() command."
      ;;
  esac
}

edit_projection () {
  PROJECTIONIST_DIR="$HOME/dotfiles/vim/projections"
  if [ -f "$PROJECTIONIST_DIR/"$1"_projections.json" ]; then
    $EDITOR "$PROJECTIONIST_DIR/"$1"_projections.json"
  else
    echo "The $1 projections file does not exist."
  fi

  unset PROJECTIONIST_DIR
}

edit_zsh () {
  ZSH_DIR="$HOME/dotfiles/zsh"
  case $1 in
    mod*|module*)
      $EDITOR "$ZSH_DIR/etc/$2.zsh"
      ;;
    comp*|completion*)
      $EDITOR "$ZSH_DIR/zsh-completions/_$2"
      ;;
    profile|prof*)
      $EDITOR "$HOME/.zprofile"
      ;;
    rc)
      $EDITOR "$HOME/.zshrc"
      ;;
    login)
      $EDITOR "$HOME/.zlogin"
      ;;
    *)
      echo "Beep-boop! Error...zzzt....$1 is not an editable option at the moment."
      ;;
  esac
  unset ZSH_DIR
}

edit_config () {
  case $1 in
    agignore)
      $EDITOR "$HOME/.agignore"
      ;;
    archey*)
      $EDITOR "$HOME/.config/archey3.cfg"
      ;;
    asound)
      $EDITOR "$HOME/.asoundrc"
      ;;
    bg|background|backgr*)
      $EDITOR "$HOME/.config/nitrogen/bg-saved.cfg"
      ;;
    bash)
      $EDITOR "$HOME/.bashrc"
      ;;
    bar)
      $EDITOR "$HOME/scripts/panel"
      ;;
    bspwm|bsp*)
      bspwmrc
      ;;
    gem)
      $EDITOR "$HOME/.gemrc"
      ;;
    gitconfig|gconf*)
      $EDITOR "$HOME/.gitconfig"
      ;;
    gitignore|gig*)
      $EDITOR "$HOME/.gitignore"
      ;;
    ignore)
      $EDITOR "$HOME/.ignore"
      ;;
    init)
      $EDITOR "$HOME/.xinitrc"
      ;;
    mutt)
      $EDITOR "$HOME/.muttrc"
      ;;
    neovim|nvim|neo*)
      nvimrc
      ;;
    nitro*)
      $EDITOR "$HOME/.config/nitrogen/nitrogen.cfg"
      ;;
    resources)
      $EDITOR "$HOME/.Xresources"
      ;;
    pry)
      $EDITOR "$HOME/.pryrc"
      ;;
    ranger)
      $EDITOR "$HOME/.config/ranger/rc.conf"
      ;;
    ssh)
      $EDITOR "$HOME/.ssh/config"
      ;;
    stalone*)
      $EDITOR "$HOME/.stalonetrayrc"
      ;;
    sxhkd*|sxh*|keys|keybind*|keymaps*)
      sxhkdrc
      ;;
    tags)
      $EDITOR "$HOME/.ctags"
      ;;
    termite)
      $EDITOR "$HOME/.config/termite/config"
      ;;
    tmux)
      $EDITOR "$HOME/.tmux.conf"
      ;;
    vim)
      vimrc
      ;;
    vimp*|vimperator)
      $EDITOR "$HOME/.vimperatorrc"
      ;;
    warp*)
      $EDITOR "$HOME/.warprc"
      ;;
    yaourt*)
      $EDITOR "$HOME/.yaourtrc"
      ;;
    zsh|zshrc)
      zshrc
      ;;
    *)
      echo "Beep-boop! Error...zzzt....$1 is not an editable option at the moment."
      ;;
  esac
}

edit_story () {
  STORY_DIR="$HOME/Dropbox/Some/Story"
  case $1 in
    about)
      $EDITOR "$STORY_DIR/About/$2"
      ;;
    arc*)
      $EDITOR "$STORY_DIR/Arcs/$2"
      ;;
    char*|profile*)
      $EDITOR "$STORY_DIR/Character_Profiles/$2"
      ;;
    idea*)
      $EDITOR "$STORY_DIR/Ideas/$2"
      ;;
    item*|artifact*)
      $EDITOR "$STORY_DIR/Items_Artifacts/$2"
      ;;
    snippet*|excerpt*)
      $EDITOR "$STORY_DIR/Snippets/$2"
      ;;
    template*)
      $EDITOR "$STORY_DIR/Templates/$2"
      ;;
    world*)
      case $2 in
        fauna|animals)
          $EDITOR "$STORY_DIR/World_Building/Fauna/$3"
          ;;
        flora|plant*|vege*)
          $EDITOR "$STORY_DIR/World_Building/Flora/$3"
          ;;
        loc*|countr*|place*)
          $EDITOR "$STORY_DIR/World_Building/Locations/$3"
          ;;
        *)
          echo "ERROR: Can you guys what the error is?"
      esac
      ;;
    *)
      echo "Not a valid section of the Story project."
      ;;
  esac
}

edit_new () {
  case $1 in
    script*)
      $EDITOR ~/scripts/$2
      ;;
    projection|proj*)
      $EDITOR ~/dotfiles/vim/projections/$2_projections.json
      ;;
    *)
      echo "Invalid thing. Cannot be edited."
      ;;
  esac
}

edit_notes () {
  case $1 in
    list)
      l ~/Documents/Notes
      ;;
    new)
      shift 1
      if [[ $1 == *.md ]] || [[ $1 == *.txt ]]; then
        $EDITOR ~/Documents/Notes/$1
      else
        echo "[!] ERROR: specify markdown or text filetype."
      fi
      ;;
    mv|move)
      shift 1
      case $1 in
        -r|--rev|--reverse)
          shift 1
          mv ~/Documents/Notes/$1 .
          shift 1
          ;;
        *)
          mv "$1" ~/Documents/Notes
          shift 1
          ;;
      esac
      ;;
    *)
      file=''
      if [ -f "$HOME/Documents/Notes/$1.md" ]; then
        file="$1.md"
      elif [ -f "$HOME/Documents/Notes/$1.txt" ]; then
        file="$1.txt"
      else
        echo "[!] ERROR: 404 - File not found."
      fi

      if [ ! -z $file ]; then
        $EDITOR ~/Documents/Notes/$file
      fi
      ;;
  esac
}
