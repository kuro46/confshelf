import os

proc appDir*(): string = expandTilde("~/.confshelf")

proc confPath*(): string = appDir() / "config.toml"

proc knownLinksPath*(): string = appDir() / "known_links.toml"
