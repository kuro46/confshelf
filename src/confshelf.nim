let doc = """
The configuration file manager

Usage:
  confshelf [--debug] manage <source> <conf-id>
  confshelf [--debug] unmanage <conf-id>
  confshelf [--debug] link <conf-id> <dest>
  confshelf [--debug] unlink <symlink>
  confshelf [--debug] (s | status)
  confshelf (-h | --help)
  confshelf (-v | --version)

Options:
  -h --help     Show this screen.
  -v --version  Show version.
  --debug       Enable debug logging.
"""
let initialConfig = """
# Configuration format version.
# DO NOT MODIFY
config_version = 1

# Repository path. The path doesn't have to be a git repository.
# You can use '~' for home directory.
repository_path = ""
"""

import docopt
import nimblefile
import os
import parsetoml
import logging
import tables
import sequtils
import strutils
import knownlinks
import apppaths

type
  Config = object
    configVersion: int
    repositoryPath: string
  ConfshelfError* = object of CatchableError
  ConfigError* = object of ConfshelfError
  ManageError* = object of ConfshelfError
  LinkError* = object of ConfshelfError

proc pathExists(path: string): bool =
  try:
    discard getFileInfo(path, followSymlink = false)
    return true
  except OSError:
    return false

proc readConfig(): Config =
  let rootTable = parsetoml.parseFile(confPath())
  let configVersion = rootTable["config_version"].getInt()
  let repositoryPath = expandTilde(rootTable["repository_path"].getStr())
  if repositoryPath == "":
    raise newException(ConfigError, "'repository_path' is empty! Please edit configuration!")
  if not dirExists(repositoryPath):
    raise newException(ConfigError, "'repository_path' is not a directory!")
  return Config(configVersion: configVersion, repositoryPath: repositoryPath)

proc initConfigIfNeeded() =
  createDir(appDir())
  let confPath = confPath()
  if not fileExists(confPath):
    writeFile(confPath, initialConfig)

proc manage(config: Config, source, confId: string) =
  # Check for source
  if not fileExists(source) or symlinkExists(source):
    raise newException(ManageError, "source file must be a regular file!")
  # Check for confId
  if confId.contains(DirSep):
    raise newException(ManageError, "conf-id mustn't include directory separator character!")
  let dest = config.repository_path / confId
  if pathExists(dest):
    raise newException(ManageError, "conf-id already exists!")
  moveFile(source, dest)
  createSymlink(dest, source)
  insertKnownLink(source, confId)

proc link(config: Config, confId: string, dest: string) =
  # Check for confId
  if confId.contains(DirSep):
    raise newException(LinkError, "conf-id mustn't include directory separator character!")
  let confIdPath = config.repository_path / confId
  if not fileExists(confIdPath):
    raise newException(LinkError, "Could not find conf-id!")
  # Check for dest
  if pathExists(dest):
    raise newException(LinkError, "Destination: \"" & dest & "\" already exists!")
  createSymlink(confIdPath, dest)
  insertKnownLink(dest, confId)

proc unlink(config: Config, symlink: string) =
  ## Replace ``symlink`` with a file that ``symlink`` pointed to.
  ## Raises ``ConfshelfError``
  ## if a path that ``symlink`` pointed to is not starts with ``config.repository_path``
  let expanded = expandSymlink(symlink)
  if not expanded.startsWith(config.repository_path):
    raise newException(ConfshelfError, "'$#' not starts with '$#'" % [expanded,
        config.repository_path])
  removeFile(symlink)
  copyFile(expanded, symlink)
  deleteKnownLink(symlink)

proc unmanage(config: Config, confId: string) =
  if confId.contains(DirSep):
    raise newException(ConfshelfError, "conf-id mustn't contain DirSep")
  let confIdPath = config.repository_path / confId
  if not fileExists(confIdPath):
    raise newException(ConfshelfError, "confIdPath not exists (or its not a file)")
  let knownLinks = readKnownLinks()
  if not knownLinks.hasKey(confId):
    raise newException(ConfshelfError, "No known links exist (Couldn't unmanage it!)")
  else:
    let symlinks = knownLinks[confId]
    for symlink in symlinks:
      removeFile(symlink)
      copyFile(confIdPath, symlink)
      deleteKnownLink(symlink)
    removeFile(confIdPath)

proc walkFilesUnderRepo(config: Config, pattern: string): seq[string] =
  toSeq(walkFiles(config.repository_path / pattern))

proc status(config: Config) =
  echo "Repository: $#" % [config.repository_path]
  let knownLinks = readKnownLinks()
  for file in walkFilesUnderRepo(config, "*") & walkFilesUnderRepo(config, ".*"):
    let confId = splitPath(file).tail
    echo confId & ":"
    if knownLinks.hasKey(confId):
      let symlinks = knownLinks[confId]
      for symlink in symlinks:
        echo "  - " & symlink
    else:
      echo "  No known links exist"

proc main() =
  # Init logger
  let consoleLogger = newConsoleLogger(levelThreshold = lvlAll)
  when defined(release):
    consoleLogger.levelThreshold = lvlInfo
  addHandler(consoleLogger)
  # Parse args
  let args = docopt(doc, version = "confshelf " & nimblefile.version)
  # Enable debug logging if --debug is specified
  if args["--debug"]:
    consoleLogger.levelThreshold = lvlAll
    debug("Debug logging enabled")
  # Config
  debug("Initializing configuration (if needed)")
  initConfigIfNeeded()
  debug("Reading configuration")
  let config = readConfig()
  debug("Config: " & $config)

  if args["manage"]:
    let source = $args["<source>"]
    let confId = $args["<conf-id>"]
    echo "Managing file: '$#' as config-id: '$#'" % [source, confId]
    manage(config, source, confId)
    echo "Success!"
  elif args["unmanage"]:
    unmanage(config, $args["<conf-id>"])
    echo "Success!"
  elif args["link"]:
    let confId = $args["<conf-id>"]
    let dest = $args["<dest>"]
    echo "Linking config: '$#' to dest: '$#'" % [confId, dest]
    link(config, confId, dest)
    echo "Success!"
  elif args["unlink"]:
    let symlink = $args["<symlink>"]
    unlink(config, symlink)
    echo "Success!"
  elif args["status"] or args["s"]:
    status(config)

main()
