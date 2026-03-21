#!/usr/bin/env node

const { existsSync, mkdirSync, cpSync, readFileSync, appendFileSync, writeFileSync, rmSync } = require('fs')
const { resolve, join } = require('path')
const { homedir } = require('os')

const packageDir = resolve(__dirname, '..')
const home = homedir()
const installDir = join(home, '.spawn')
const sourceLine = 'source "$HOME/.spawn/spawn.sh"'
const marker = '.spawn/spawn.sh'

// Determine shell rc file
const shell = process.env.SHELL || ''
const rcFile = shell.includes('zsh')
  ? join(home, '.zshrc')
  : join(home, '.bashrc')

// Copy runtime files to ~/.spawn/
mkdirSync(installDir, { recursive: true })

const pkg = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'))

try {
  cpSync(join(packageDir, 'spawn.sh'), join(installDir, 'spawn.sh'))
  writeFileSync(join(installDir, 'VERSION'), pkg.version + '\n')

  const libDest = join(installDir, 'lib')
  if (existsSync(libDest)) rmSync(libDest, { recursive: true })
  cpSync(join(packageDir, 'lib'), libDest, { recursive: true })
} catch (err) {
  console.error('spawn: failed to copy runtime files:', err.message)
  process.exit(0)
}

// Add source line to shell rc if not already present
try {
  const rcContent = existsSync(rcFile) ? readFileSync(rcFile, 'utf8') : ''
  if (!rcContent.includes(marker)) {
    appendFileSync(rcFile, `\n# spawn\n${sourceLine}\n`)
  }
} catch {
  // Non-fatal: user can add the source line manually
}

console.log(`spawn v${pkg.version} installed. Restart your shell or run: source ${rcFile}`)
console.log(`\n💡 Pro tip: if you use the default nested layout, add worktrees to your .gitignore:\n   echo ".worktrees/" >> .gitignore`)
