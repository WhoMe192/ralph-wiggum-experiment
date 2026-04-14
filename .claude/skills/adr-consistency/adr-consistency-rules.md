## Step 2: Check for Contradictions

**Direct Contradictions**:

- Two ADRs make opposite decisions on the same topic
- Example: one requires authentication via <datastore> session tokens; another mandates stateless
  JWT-only auth

**Implicit Conflicts**:

- Two ADRs that cannot both be satisfied in the same running system
- Detection rule: if implementing ADR A and ADR B simultaneously would require changing or disabling a mechanism each ADR mandates, flag as MAJOR
- Example: one ADR mandates zero-downtime deployments via rolling update; another mandates a deployment process that requires a `tofu destroy` + `tofu apply` cycle

**Scope Overlaps**:

- Two or more ADRs each contain a Decision section that starts with "We will..." and both sentences apply to the same resource type or system component — flag as MAJOR
- Example: two ADRs both make decisions about session token storage without one superseding the other

**Dependency Violations**:

- ADR B assumes or depends on a decision from ADR A, but A is Superseded or Rejected
- Missing prerequisite decisions

**Temporal Inconsistencies**:

- A later ADR contradicts an earlier one without superseding it
- An ADR marked Accepted references a decision that has since changed