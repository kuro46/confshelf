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

type
  Config = object
    configVersion: int
    repositoryPath: string
  ConfigRef = ref Config
  ConfshelfError* = object of CatchableError
  ConfigError* = object of ConfshelfError
  ManageError* = object of ConfshelfError
  LinkError* = object of ConfshelfError

proc appDir(): string = expandTilde("~/.confshelf")

proc confPath(): string = appDir() / "config.toml"

proc knownLinksPath(): string = appDir() / "known_links.toml"

proc pathExists(path: string): bool =
  try:
    discard getFileInfo(path, followSymlink = false)
    return true
  except OSError:
    return false

proc readConfig(): ConfigRef =
  let rootTable = parsetoml.parseFile(confPath())
  let configVersion = rootTable["config_version"].getInt()
  let repositoryPath = expandTilde(rootTable["repository_path"].getStr())
  if repositoryPath == "":
    raise newException(ConfigError, "'repository_path' is empty! Please edit configuration!")
  if not dirExists(repositoryPath):
    raise newException(ConfigError, "'repository_path' is not a directory!")
  return ConfigRef(configVersion: configVersion, repositoryPath: repositoryPath)

proc readKnownLinks(): Table[string, seq[string]] =
  let knownLinksPath = knownLinksPath()
  if not fileExists(knownLinksPath):
    return initTable[string, seq[string]](initialSize = 0)
  let table = parsetoml.parseFile(knownLinksPath).tableVal
  let confIds = toSeq(table.values()).deduplicate().map(proc(
      x: TomlValueRef): string = x.getStr())
  result = initTable[string, seq[string]](initialSize = confIds.len())
  for confId in confIds:
    var symlinks = newSeq[string]();
    for key, tomlValue in table.pairs:
      if confId == tomlValue.stringVal:
        symlinks.add(key)
    result[confId] = symlinks
  return result

proc initConfigIfNeeded() =
  createDir(appDir())
  let confPath = confPath()
  if not fileExists(confPath):
    writeFile(confPath, initialConfig)

proc insertKnownLink(symlinkPath: string, confId: string) =
  let file = open(knownLinksPath(), fmAppend)
  defer: close(file)
  file.write("\"" & symlinkPath.absolutePath() & "\" = \"" & confId & "\"\n")

proc manage(config: ConfigRef, source: string, confId: string) =
  debug("Managing source: " & source & " conf-id: " & confId)
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
  echo "Success!"

proc link(config: ConfigRef, confId: string, dest: string) =
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
  echo "Success!"

proc walkFilesUnderRepo(config: ConfigRef, pattern: string): seq[string] =
  toSeq(walkFiles(config.repository_path / pattern))

proc status(config: ConfigRef) =
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
  debug("Config: " & $config[])

  if args["manage"]:
    let source = $args["<source>"]
    let confId = $args["<conf-id>"]
    manage(config, source, confId)
  if args["unmanage"]:
    echo "unmanage"
  if args["link"]:
    let confId = $args["<conf-id>"]
    let dest = $args["<dest>"]
    link(config, confId, dest)
  if args["unlink"]:
    echo "unlink"
  if args["status"] or args["s"]:
    status(config)

main()
