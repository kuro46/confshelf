#!/usr/bin/env nim

# Helper for managing dotfiles.
# https://github.com/kuro46/confshelf

import tables
import strutils
import os
import distros

proc hasParam(params: varargs[string]): bool =
  for param in params:
    if commandLineParams().contains(param):
      return true

if hasParam("-h", "--help"):
  echo "--help | -h         : Show this message"
  echo "--create-config     : Generate configration file with some instructions"
  echo "--no-overwrite | -n : Don't overwrite regular file without confirmation"
  echo "                      This is useful when you want to generate absent symlinks or update symlink"
  echo "                      NOTE: Symbolic links will be overwritten even if this flag is set"
  echo "--update            : Download latest script to ./setup.nims"
  quit(0)

if hasParam("--update"):
  echo "Downloading latest script from https://raw.githubusercontent.com/kuro46/confshelf/main/setup.nims"
  let (output, exit) = gorgeEx "wget -O setup.nims https://raw.githubusercontent.com/kuro46/confshelf/main/setup.nims"
  if exit != 0:
    echo output
    echo ""
    echo "Execution failed."
    quit(1)
  echo "Downloaded!"
  quit(0)

if hasParam("--create-config"):
  if fileExists("./links.conf"):
    echo "./links.conf already exists. Did nothing."
    quit(0)
  let header = """
# This is script-like configuration file for describe file mappings.
#
# There is 'link' function for describe file mapping.
# First argument for 'link' is a path of symlink.
# Second argument for 'link' is a relative path form repository.
#
# For example, If repository is '~/dotfiles' and you want to create symbolic link in
# '~/just_a_symlink' that points to '~/dotfiles/foo', you should add line like below.
#
#link "~/just_a_link", "foo"
#
# Then, you can execute `./setup.nims` to create symbolic links based on this configuration file.
# NOTE: If you just added an entry to this configuration file, 
#       It is useful to execute `./setup.nims` with `--no-overwrite` flag.
#       For more details, execute setup script with `--help` flag.

"""
  writeFile("./links.conf", header)
  echo "./links.conf created."
  quit(0)

let noOverwrite = hasParam("-n", "--no-overwrite")

type FileType = enum
  SymbolicLink
  RegularFile
  Directory
  Unknown
  NotExists ## Usually if stat returned 1

proc getFileType(file: string): FileType =
  if detectOs(FreeBSD):
    let (output, exitCode) = gorgeEx "stat -f=%T " & file
    if exitCode == 1:
      return FileType.NotExists
    case output
    of "":
      return FileType.RegularFile
    of "/":
      return FileType.Directory
    of "@":
      return FileType.SymbolicLink
    else:
      return FileType.Unknown
  else:
    let (output, exitCode) = gorgeEx "stat --format=%F " & file
    if exitCode == 1:
      return FileType.NotExists
    case output
    of "regular file":
      return FileType.RegularFile
    of "symbolic link":
      return FileType.SymbolicLink
    of "directory":
      return FileType.Directory
    else:
      return FileType.Unknown

proc link(symlink, confId: string) =
  echo "Creating a symlink '$#' which points to '$#'" % [symlink, confId]
  let expandedSymlink = expandTilde(symlink)
  if dirExists(expandedSymlink):
    echo "'$#' is a directory." % expandedSymlink
    return
  let symlinkFileType = getFileType(expandedSymlink)
  if symlinkFileType == FileType.RegularFile:
    if noOverwrite:
      echo "  SKIPPED because '$#' already exists and '--no-overwrite' flag is set. Did nothing." % symlink
      return
    echo "  '$#' already exists. Do you want to overwrite? " % symlink &
      "(Please type 'Yes' and [Enter] if you want to do)"
    let userInput = readLineFromStdin().toLowerAscii()
    if userInput != "yes":
      echo "  SKIPPED"
      return
  elif symlinkFileType == FileType.Unknown or symlinkFileType == FileType.Directory:
    echo "  SKIPPED because filetype of '$#' is $#" % [symlink, $symlinkFileType]
    return
  # symlinkFileType is RegularFile or SymbolicLink
  let confPath = getCurrentDir() / confId
  if not fileExists(confPath):
    echo "  SKIPPED because configuration '$#' doesn't exist. Did nothing." % confId
    return
  exec "mkdir -p $#" % (expandedSymlink /../ "")
  exec "ln -fs $# $#" % [confPath, expandedSymlink]
  echo "  CREATED symlink '$#' points to '$#'" % [symlink, confPath]
# Load links
include ./links.conf
#echo $getFileType("~")
#echo $getFileType("~/.vimrc")
#echo $getFileType("~/.ssh/config")
