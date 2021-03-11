# confshelf

confshelf is a simple tool for manage setting files (Can use as dotfiles manager).

Tested on FreeBSD 12.2-RELEASE-p3

## Download pre-built binary

### FreeBSD

```
curl -Lo confshelf https://github.com/kuro46/confshelf/releases/download/v0.1.0/confshelf-freebsd-x86_64
chmod +x confshelf
```

### Linux

```
curl -Lo confshelf https://github.com/kuro46/confshelf/releases/download/v0.1.0/confshelf-linux-x86_64
chmod +x confshelf
```

Then, place downloaded binary into `$PATH`

## Commands

```
$ confshelf -h
confshelf [--debug] manage <source> <conf-id>
confshelf [--debug] unmanage <conf-id>
confshelf [--debug] link <conf-id> <dest>
confshelf [--debug] unlink <symlink>
confshelf [--debug] (s | status)
confshelf (-h | --help)
confshelf (-v | --version)
```

### `confshelf manage <source> <conf-id>`

Manage `<source>`.

`<source>` is a path to regular file.  
`<conf-id>` is a string identifier of `<source>`.

**Behavior:**

Move `<source>` to `repository_path/<conf-id>`
and create symlink in `<source>` that point to `repository_path/<dest>`

(`repository_path` is a value of `repository_path` in config.toml)

### `confshelf unmanage <conf-id>`

Unmanage configuration file specified via `<conf-id>`.

**Behavior:**

This command will replace known symlinks with `repository_path/<conf-id>`
and remove `repository_path/<conf-id>`.

### `confshelf link <conf-id> <dest>`

Link configuration file to destination.

**Behavior:**

Create a symlink at `<dest>` that point to `repository_path/<conf-id>`

### `confshelf unlink <symlink>`

Unlink symlink.

**Behavior:**

Remove `<symlink>`. Fails when destination of symlink is not managed by confshelf.

### `confshelf status`

Print git status(if git repo), known symlinks for each files that managed by confshelf.

## Configuration

Configuration file is `~/.confshelf/config.toml`

```toml
# Configuration format version.
# DO NOT MODIFY
config_version = "1"

# Repository path. The path doesn't have to be a git repository.
# You can use '~' for home directory.
repository_path = "~/dotfiles"
```

## Files

- `~/.confshelf/config.toml` Config file
- `~/.confshelf/known_links.toml` A file stores known symlink files

