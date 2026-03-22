#!/usr/bin/env node

const {
  appendFileSync,
  cpSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  renameSync,
  rmSync,
  writeFileSync,
} = require('fs')
const { homedir } = require('os')
const { join, resolve } = require('path')

function detectRcFile(homeDir, shell) {
  return shell.includes('zsh')
    ? join(homeDir, '.zshrc')
    : join(homeDir, '.bashrc')
}

function loadPackageVersion(packageDir) {
  let pkg
  try {
    pkg = JSON.parse(readFileSync(join(packageDir, 'package.json'), 'utf8'))
  } catch (err) {
    throw new Error(`could not read package.json: ${err.message}`)
  }

  if (!pkg.version) {
    throw new Error('package.json is missing a version')
  }

  return pkg.version
}

function copyRuntimeFiles(packageDir, installDir, version) {
  const tempDir = mkdtempSync(join(installDir, '.install-'))
  const libDest = join(installDir, 'lib')

  try {
    cpSync(join(packageDir, 'spawn.sh'), join(tempDir, 'spawn.sh'))
    writeFileSync(join(tempDir, 'VERSION'), version + '\n')
    cpSync(join(packageDir, 'lib'), join(tempDir, 'lib'), { recursive: true })

    rmSync(join(installDir, 'spawn.sh'), { force: true })
    rmSync(join(installDir, 'VERSION'), { force: true })
    rmSync(libDest, { force: true, recursive: true })

    renameSync(join(tempDir, 'spawn.sh'), join(installDir, 'spawn.sh'))
    renameSync(join(tempDir, 'VERSION'), join(installDir, 'VERSION'))
    renameSync(join(tempDir, 'lib'), libDest)
  } catch (err) {
    throw new Error(`failed to copy runtime files: ${err.message}`)
  } finally {
    rmSync(tempDir, { force: true, recursive: true })
  }
}

function ensureSourceLine(rcFile, sourceLine, marker, ignoreErrors) {
  try {
    const rcContent = existsSync(rcFile) ? readFileSync(rcFile, 'utf8') : ''
    if (!rcContent.includes(marker)) {
      appendFileSync(rcFile, `\n# spawn\n${sourceLine}\n`)
    }
  } catch (err) {
    if (!ignoreErrors) {
      throw new Error(`failed to update shell rc file: ${err.message}`)
    }
  }
}

function installRuntime(options = {}) {
  const packageDir = resolve(options.packageDir || join(__dirname, '..'))
  const homeDir = options.homeDir || homedir()
  const shell = options.shell || process.env.SHELL || ''
  const ignoreRcErrors = options.ignoreRcErrors === true
  const sourceLine = 'source "$HOME/.spawn/spawn.sh"'
  const marker = '.spawn/spawn.sh'
  const installDir = join(homeDir, '.spawn')

  mkdirSync(installDir, { recursive: true })

  const version = loadPackageVersion(packageDir)
  copyRuntimeFiles(packageDir, installDir, version)

  const rcFile = detectRcFile(homeDir, shell)
  ensureSourceLine(rcFile, sourceLine, marker, ignoreRcErrors)

  return { rcFile, version }
}

function parseArgs(argv) {
  const options = {
    packageDir: join(__dirname, '..'),
    print: '',
    ignoreRcErrors: true,
  }

  while (argv.length > 0) {
    const arg = argv.shift()
    switch (arg) {
      case '--package-dir':
        if (argv.length === 0) {
          throw new Error('missing value for --package-dir')
        }
        options.packageDir = argv.shift()
        break
      case '--print':
        if (argv.length === 0) {
          throw new Error('missing value for --print')
        }
        options.print = argv.shift()
        break
      case '--strict-rc':
        options.ignoreRcErrors = false
        break
      default:
        throw new Error(`unknown option: ${arg}`)
    }
  }

  return options
}

if (require.main === module) {
  try {
    const options = parseArgs(process.argv.slice(2))
    const result = installRuntime(options)

    if (options.print === 'version') {
      process.stdout.write(result.version)
    } else if (options.print === 'rc-file') {
      process.stdout.write(result.rcFile)
    }
  } catch (err) {
    console.error(err.message)
    process.exit(1)
  }
}

module.exports = {
  detectRcFile,
  installRuntime,
}
