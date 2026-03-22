#!/usr/bin/env node

const { installRuntime } = require('./install-runtime')

let result

try {
  result = installRuntime({ ignoreRcErrors: true })
} catch (err) {
  console.error('spawn:', err.message)
  process.exit(1)
}

console.log(`spawn v${result.version} installed. Restart your shell or run: source ${result.rcFile}`)
console.log(`\n💡 Pro tip: add worktrees to your .gitignore:\n   echo ".worktrees/" >> .gitignore`)
