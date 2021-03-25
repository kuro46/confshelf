#!/usr/bin/env nim

# Helper for managing dotfiles.
# https://github.com/kuro46/confshelf

import tables
import strutils
import os

proc hasParam(params: varargs[string]): bool =
  for param in params:
    if commandLineParams().contains(param):
      return true

if hasParam("-h", "--help"):
  echo "--help | -h         : Show this message"
  echo "--create-config     : Generate configration file with some instructions"
  echo "--no-overwrite | -n : Don't overwrite file/symlinks that already exist"
  echo "                      This is useful when you want to generate absent symlinks"
  echo "                      NOTE: This won't remove symlinks that absented from links.nims"
  echo "--check-update      : Check update of this script(NOT IMPLEMENTED)"
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
# NOTE: If you just updated this configuration file, 
#       It is useful to execute `./setup.nims` with `--no-overwrite` flag.
#       For more details, execute setup script with `--help` flag.

"""
  writeFile("./links.conf", header)
  echo "./links.conf created."
  quit(0)

let noOverwrite = hasParam("-n", "--no-overwrite")

proc link(symlink, confId: string) =
  echo "Creating a symlink '$#' which points to '$#'" % [symlink, confId]
  let expandedSymlink = expandTilde(symlink)
  if dirExists(expandedSymlink):
    echo "'$#' is a directory." % expandedSymlink
  if fileExists(expandedSymlink):
    if noOverwrite:
      echo "  '$#' already exists and '--no-overwrite' flag is set. Did nothing." % symlink
      return
    echo "- '$#' already exists. Do you want to overwrite? " % symlink &
      "(Please type 'Yes' and [Enter] if you want to do)"
    let userInput = readLineFromStdin().toLowerAscii()
    if userInput != "yes":
      echo "  Did nothing."
      return
  let confPath = thisDir() / confId
  if not fileExists(confPath):
    echo "  Configuration '$#' doesn't exist. Did nothing." % confId
    return
  exec "mkdir -p $#" % (expandedSymlink /../ "")
  exec "ln -fs $# $#" % [confPath, expandedSymlink]
  echo "  Created symlink '$#' points to '$#'" % [symlink, confPath]
# Load links
include ./links.conf

