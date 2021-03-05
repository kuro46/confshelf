# confshelf

confshelf is a simple tool for manage setting files (Can use as dotfiles manager).

Requires libgit2  
Tested on FreeBSD 12.2-RELEASE-p3

## ToDo

- Read configuration file
- Handle absolute path
- Set repository path

## Commands

### `confshelf setup` 

Setup confshelf in interactive interface.  
You can choose whether initialize or clone repository.

### `confshelf pull`

Pull from remote repository

### `confshelf push`

Push to remote repository

### `confshelf commit [message]`

Commit files in interactive interface.  
You can select files to stage.

### `confshelf manage <source path> <dest path>`

Move `<source path>` to `<dest path>` and create symlink in `<source path>` that point to `<dest path>`

`<dest path>` must be relative path or absolute path that starts with `~/.confshelf/repo/`

### `confshelf unmanage <file path>`

`<file path>` must be relative or starts with `~/.confshelf/repo/`.  

This command will replace known symlinks with `<file path>` and remove `<file path>`.

### `confshelf link <source path> <symlink path>

Create a symlink in `<symlink path>` that point to `<source path>`

`<source path` must be relative or starts with `~/.confshelf/repo/`

### `confshelf status`

Print git status, known symlinks for each files that managed by confshelf.

## Configuration

Configuration file is `~/.confshelf/config.toml`

```toml
# Configuration format version.
# DO NOT MODIFY
config_version = "1"

# Repository path. The path doesn't have to be a git repository.
repository_path = "/home/foo/.confshelf/repo"
```

## Files

- `~/.confshelf/repo/` Git repo
- `~/.confshelf/config.toml` Config file
- `~/.confshelf/known_links.toml` A file stores known symlink files

