#!/usr/bin/env node

const { installRuntime } = require('./install-runtime')

try {
  const result = installRuntime({ ignoreRcErrors: true })
  console.log(`spawn v${result.version} installed.`)
} catch (err) {
  console.error('spawn:', err.message)
  process.exit(1)
}
