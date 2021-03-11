## Utilities for processing known_links.toml

import tables
import os
import parsetoml
import sequtils
import apppaths

type
  KnownLinks* = TableRef[string, seq[string]]

proc readKnownLinks*(): KnownLinks =
  let knownLinksPath = knownLinksPath()
  if not fileExists(knownLinksPath):
    return newTable[string, seq[string]](initialSize = 0)
  let table = parsetoml.parseFile(knownLinksPath).tableVal
  let confIds = toSeq(table.values()).deduplicate().map(proc(
      x: TomlValueRef): string = x.getStr())
  result = newTable[string, seq[string]](initialSize = confIds.len())
  for confId in confIds:
    var symlinks = newSeq[string]();
    for key, tomlValue in table.pairs:
      if confId == tomlValue.stringVal:
        symlinks.add(key)
    result[confId] = symlinks
  return result

proc insertKnownLink*(symlinkPath: string, confId: string) =
  let file = open(knownLinksPath(), fmAppend)
  defer: close(file)
  file.write("\"" & symlinkPath.absolutePath() & "\" = \"" & confId & "\"\n")

proc writeKnownLinks*(links: KnownLinks) =
  let knownLinksPath = knownLinksPath()
  removeFile(knownLinksPath)
  for confId, symlinks in links.pairs:
    for symlink in symlinks:
      insertKnownLink(symlink, confId)

proc deleteKnownLink*(symlinkPath: string) =
  var knownLinks = readKnownLinks()
  let absoluteSymlinkPath = symlinkPath.absolutePath()
  for confId, symlinks in knownLinks.mpairs:
    var idx = -1
    var found = false
    for symlink in symlinks:
      idx = idx + 1
      if symlink == absoluteSymlinkPath:
        found = true
        break
    if found: symlinks.delete(idx)
  writeKnownLinks(knownLinks)
