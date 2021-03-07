# https://qiita.com/6in/items/fb8bb4f6f1e534933266#comment-a63b85845444f2ee5e80
var
  packageName: string
  version*: string
  author: string
  description: string
  license: string
  srcdir: string
  binDir: string
  backend: string

  skipDirs, skipFiles, skipExt, installDirs, installFiles, installExt, bin: seq[string]
  requiresData: seq[string]
  foreignDeps: seq[string]

proc requires(deps: varargs[string]) = discard
template task(name: untyped; description: string; body: untyped): untyped = discard
template before(action: untyped, body: untyped): untyped = discard
template after(action: untyped, body: untyped): untyped = discard
template builtin = discard
proc getPkgDir(): string = discard

include ../confshelf.nimble
{. hint[XDeclaredButNotUsed]:off .}
