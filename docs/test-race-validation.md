# Flow SDK Test Race Validation

## Baseline
- [ ] Record serial test stability.
- [ ] Identify access to shared Flow actor instances.

## Refactor
- [ ] Tests own or inject FlowAccessActor instances.
- [ ] Tests do not mutate shared global actor state.
- [ ] Parallel test execution is enabled.

## Acceptance
- [ ] Run `swift test` ten consecutive times with no failures.
- [ ] Remove the serial-only workaround only after repeatable parallel success.
