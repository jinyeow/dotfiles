# How to load an Elixir library into IEx without having to create a Mix Project

## Steps:
  1) Get their sources from Github, git checkout to the last release and compile them.
  2) Once compilation is over, create ~/.mix/beam/ and move the .beam files into this directory.
  3) Thankfully, iex is just a shell script. If you happen to have a custom $PATH
     variable that points to ~/.local/bin, then copy iex to this directory and
     rename it to something like "deviex".
     Then in your custom "deviex", move to the last line and change it to…
      'exec elixir --no-halt --erl "-user Elixir.IEx.CLI" -pa "$HOME/.mix/beam" +iex "$@"'
    And now it will load the .beam files located at ~/.mix/beam at startup.

Note: The reason why we use a different script for IEx is to avoid name
conflicts with installed libs in the projects you'll work on with regular iex.

