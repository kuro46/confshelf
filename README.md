# sfm (Setting Files Manager)

sfm is a simple tool for manage setting files (Can be used for dotfiles management).

## Commands

### `sfm repo init` 

Init git repository in `~/.config/sfm/repo/`

### `sfm repo clone <source repo>`

Clones repository from remote/local to `~/.config/sfm/repo/`

### `sfm repo pull`

### `sfm repo push`

### `sfm commit [message]`

### `sfm manage <source path> <dest path>`

Moves `<source path>` to `<dest path>` and create symlink in `<source path>` that point to `<dest path>`

`<dest path>` must be relative path or absolute path that starts with `~/.config/sfm/repo/`

### `sfm unmanage <symlink path>`

Copies a file that symlink pointed to into `<symlink path>`

### `sfm place <source path> <symlink path>

Creates a symlink in `<symlink path>` that point to `<source path>`

`<source path` must be relative or starts with `~/.config/sfm/repo/`

### `sfm ls`

List managed files and known symlinks

## Configuration

Configuration file is placed in `$XDG_CONFIG_HOME/sfm/config.toml`

```toml
# Do not modify
version = "1"
# Set whether push on commit
push_on_commit = false
```

## Files

- `$XDG_CONFIG_HOME/sfm/repo/` Git repo
- `$XDG_CONFIG_HOME/sfm/config.toml` Config file
- `$XDG_DATA_HOME/sfm/known_links.toml` A file stores known symlink files

