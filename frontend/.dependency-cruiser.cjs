/** @type {import('dependency-cruiser').IConfiguration} */
module.exports = {
  forbidden: [
    {
      name: 'no-components-importing-pages',
      severity: 'error',
      comment: 'Components must not import from pages',
      from: { path: '^src/components' },
      to: { path: '^src/pages' },
    },
    {
      name: 'no-services-importing-components',
      severity: 'error',
      comment: 'Services must not import React components',
      from: { path: '^src/services' },
      to: { path: '^src/(components|pages|hooks)' },
    },
    {
      name: 'no-circular',
      severity: 'error',
      comment: 'Circular dependencies are forbidden',
      from: {},
      to: { circular: true },
    },
  ],
  options: {
    doNotFollow: { path: 'node_modules' },
    tsPreCompilationDeps: true,
  },
}
