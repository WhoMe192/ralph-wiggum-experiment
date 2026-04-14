'use strict';
const yaml = require('js-yaml');

/**
 * Parse and validate a 00-pipeline.md YAML string.
 * Returns a pipeline object: { phase, description, max_retries_per_step, steps, tests }
 */
function parsePipeline(yamlStr) {
  const doc = yaml.load(yamlStr);
  if (!doc.tests) throw new Error('Pipeline config missing required field: tests');
  if (!Array.isArray(doc.steps)) throw new Error('Pipeline config missing required field: steps');
  for (const step of doc.steps) {
    if (!step.id) throw new Error('Each step must have an id field');
    if (!Array.isArray(step.produces)) step.produces = [];
    if (!Array.isArray(step.requires)) step.requires = [];
  }
  return doc;
}

/**
 * Topologically sort steps by their produces/requires dependency graph.
 * Throws with a clear message if a circular dependency is detected.
 * Returns a new array of steps in safe execution order.
 */
function topoSort(steps) {
  // Build a map from token string → step id
  const producerOf = {};
  for (const step of steps) {
    for (const token of step.produces) {
      producerOf[token] = step.id;
    }
  }

  // Build adjacency list: step id → set of step ids it depends on
  const deps = {};
  for (const step of steps) {
    deps[step.id] = new Set();
    for (const token of step.requires) {
      const producer = producerOf[token];
      if (producer && producer !== step.id) {
        deps[step.id].add(producer);
      }
    }
  }

  // Kahn's algorithm
  const inDegree = {};
  const dependents = {}; // reverse: id → steps that depend on it
  for (const step of steps) {
    inDegree[step.id] = deps[step.id].size;
    dependents[step.id] = [];
  }
  for (const [id, depSet] of Object.entries(deps)) {
    for (const dep of depSet) {
      dependents[dep].push(id);
    }
  }

  const queue = steps.filter(s => inDegree[s.id] === 0).map(s => s.id);
  const sorted = [];
  const stepById = Object.fromEntries(steps.map(s => [s.id, s]));

  while (queue.length > 0) {
    const id = queue.shift();
    sorted.push(stepById[id]);
    for (const dependent of dependents[id]) {
      inDegree[dependent]--;
      if (inDegree[dependent] === 0) queue.push(dependent);
    }
  }

  if (sorted.length !== steps.length) {
    throw new Error('Circular dependency detected in pipeline steps');
  }

  return sorted;
}

/**
 * Validate that every required token is produced by some step.
 * Returns an array of warning strings (empty = all clear).
 */
function validateDeps(steps) {
  const allProduced = new Set(steps.flatMap(s => s.produces));
  const warnings = [];
  for (const step of steps) {
    for (const token of step.requires) {
      if (!allProduced.has(token)) {
        warnings.push(`Step "${step.id}" requires "${token}" but no step produces it`);
      }
    }
  }
  return warnings;
}

module.exports = { parsePipeline, topoSort, validateDeps };

// CLI usage: node scripts/pipeline-deps.js prompts/phase-09/00-pipeline.md
if (require.main === module) {
  const fs = require('fs');
  const filePath = process.argv[2];
  if (!filePath) { console.error('Usage: node pipeline-deps.js <00-pipeline.md>'); process.exit(1); }
  try {
    const raw = fs.readFileSync(filePath, 'utf8');
    const pipeline = parsePipeline(raw);
    const sorted = topoSort(pipeline.steps);
    const warnings = validateDeps(pipeline.steps);
    if (warnings.length > 0) {
      console.warn('Dependency warnings:');
      warnings.forEach(w => console.warn(' ', w));
    }
    console.log(JSON.stringify({ phase: pipeline.phase, steps: sorted.map(s => s.id), tests: pipeline.tests }, null, 2));
  } catch (err) {
    console.error('ERROR:', err.message);
    process.exit(1);
  }
}
