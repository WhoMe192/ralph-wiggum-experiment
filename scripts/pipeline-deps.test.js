const { parsePipeline, topoSort, validateDeps } = require('./pipeline-deps');

const SAMPLE_YAML = `
phase: "test"
description: "Sample pipeline"
max_retries_per_step: 2
steps:
  - id: "01-db"
    produces: ["db.js: getUser"]
    requires: []
  - id: "02-routes"
    produces: ["index.js: GET /users"]
    requires: ["db.js: getUser"]
  - id: "03-frontend"
    produces: ["index.html: users page"]
    requires: ["index.js: GET /users"]
tests:
  per_step: "node --check orchestrator/src/*.js"
  full_suite: "npm test"
`;

const CIRCULAR_YAML = `
phase: "circular"
description: "Circular dep test"
max_retries_per_step: 1
steps:
  - id: "01-a"
    produces: ["a.js: fnA"]
    requires: ["b.js: fnB"]
  - id: "02-b"
    produces: ["b.js: fnB"]
    requires: ["a.js: fnA"]
tests:
  per_step: "echo ok"
  full_suite: "echo ok"
`;

const OUT_OF_ORDER_YAML = `
phase: "reorder"
description: "Steps declared out of dep order"
max_retries_per_step: 1
steps:
  - id: "01-routes"
    produces: ["index.js: GET /users"]
    requires: ["db.js: getUser"]
  - id: "02-db"
    produces: ["db.js: getUser"]
    requires: []
tests:
  per_step: "echo ok"
  full_suite: "echo ok"
`;

describe('parsePipeline', () => {
  test('parses valid YAML into pipeline object', () => {
    const pipeline = parsePipeline(SAMPLE_YAML);
    expect(pipeline.phase).toBe('test');
    expect(pipeline.steps).toHaveLength(3);
    expect(pipeline.steps[0].id).toBe('01-db');
    expect(pipeline.tests.per_step).toBe('node --check orchestrator/src/*.js');
  });

  test('throws on missing required fields', () => {
    expect(() => parsePipeline('phase: "x"\nsteps: []')).toThrow(/tests/);
  });

  test('throws if a step is missing id', () => {
    const bad = `
phase: "x"
steps:
  - produces: []
    requires: []
tests:
  per_step: "echo ok"
  full_suite: "echo ok"
`;
    expect(() => parsePipeline(bad)).toThrow(/id/);
  });
});

describe('topoSort', () => {
  test('returns steps in dependency order', () => {
    const pipeline = parsePipeline(SAMPLE_YAML);
    const sorted = topoSort(pipeline.steps);
    const ids = sorted.map(s => s.id);
    expect(ids.indexOf('01-db')).toBeLessThan(ids.indexOf('02-routes'));
    expect(ids.indexOf('02-routes')).toBeLessThan(ids.indexOf('03-frontend'));
  });

  test('reorders out-of-order steps correctly', () => {
    const pipeline = parsePipeline(OUT_OF_ORDER_YAML);
    const sorted = topoSort(pipeline.steps);
    const ids = sorted.map(s => s.id);
    expect(ids.indexOf('02-db')).toBeLessThan(ids.indexOf('01-routes'));
  });

  test('throws on circular dependency', () => {
    const pipeline = parsePipeline(CIRCULAR_YAML);
    expect(() => topoSort(pipeline.steps)).toThrow(/circular/i);
  });
});

describe('validateDeps', () => {
  test('returns no warnings for valid pipeline', () => {
    const pipeline = parsePipeline(SAMPLE_YAML);
    const warnings = validateDeps(pipeline.steps);
    expect(warnings).toHaveLength(0);
  });

  test('returns warning when a required token is not produced by any step', () => {
    const pipeline = parsePipeline(SAMPLE_YAML);
    pipeline.steps[2].requires.push('missing.js: ghost');
    const warnings = validateDeps(pipeline.steps);
    expect(warnings.some(w => w.includes('missing.js: ghost'))).toBe(true);
  });
});
