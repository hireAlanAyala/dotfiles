Command I used to initialize all the config files ny home-manager
nix run home-manager/master -- init --switch

browse docs with:
man home-configuration.nix

apply your home manager changesi from any folder using:
home-manager switch

when running this home-manager will look to see if that file exists and it's not created by home-manager. It will then ask you to back it up

nix will keep a copy of your config in nix/store when you run activate your config
this means that you can traverse your environment history using:
home-manager generations

to activate a previous generation grab the path with a hash and append /activate
example:  /nix/store/rjzjszmwfrhmwzvqxhgy4l2a4rrr2xma-home-manager-generation/activate
reference this: https://ghedam.at/24353/tutorial-getting-started-with-home-manager-for-nix

You can use home manager to manage symlinks.
An example of symlinking an existing vim config (not neovim) is

(in your home.flake) home.file.".vimrc".source = path/to/file/vimrc;\

it's best practice to keep all these config files under one folder for git tracking

when you update this symlinked config file all you have to do is save it and run home-manager switch
this method allows you to write in a way thats more native to the tools you're using
the disadvantage is that you don't get type checking and safety from the home-manager tool
doing the config through home-manager can be more limiting because you're at the mercy of the open-source community updating home-managers as the options update in the tooling

A more advanced way to structure your config is to use imports to keep the main file small and readable
example: https://github.com/ghedamat/nixfiles/blob/d10cf981baf3d928e3910593d881a92f18cd39d6/nixpkgs/home-dev.nix#L18-L23

An even more advanced way is to created your own nix modules