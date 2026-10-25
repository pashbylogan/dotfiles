---
name: mutator
description: Evaluate test thoroughness using Uncle Bob's mutation-testing tool. Use for ub-mode mutation checks, uncovered mutation sites, or surviving mutants that reveal missing behavioral assertions.
---

# Mutator

This is a locally maintained integration skill, not an upstream-authored skill.
The pinned upstream CLI is installed at `~/.local/bin/mutator`; its otherwise
undeclared crapper dependency is explicitly installed in the same environment.
Read `references/upstream.md` beside this skill before a full run.

Run from the project root, starting with a small source file:

```sh
mutator --help
mutator --scan path/to/source
mutator --use-existing-coverage --max-workers 2 path/to/source
mutator --use-existing-coverage --max-workers 2 --test-command 'project-specific test command' path/to/source
```

- Supports Clojure, Java, Go, TypeScript/JavaScript, Rust, and Python.
- Inspect first with `--scan`; establish an independently passing baseline. Full runs execute project code/tests many times. Confirm scope and cost before a broad run, and inspect commands before execution.
- Default runs regenerate coverage via crapper and may install missing coverage dependencies. Prefer known current reports with `--use-existing-coverage`; disclose missing or stale coverage. Do not silently change project dependencies.
- Use bounded workers (start with 2, not the upstream one-per-core default). Worker overlays copy mutated files but link the rest of the project: they are NOT a security sandbox and test side effects may still touch shared resources.
- Snapshots live in `.metrics/mutate/`; worker overlays in `target/mutation-workers`. Never delete another run's work or uncommitted files.
- Subsequent runs are differential: survivors and changed functions rerun; unchanged killed mutants are cached. Use `--mutate-all` deliberately when fresh full evidence is needed.
- Ensure the test command actually imports the mutated worker copy. For example, a symlinked Python test script can resolve imports against the original source and falsely report survivors. Check a known kill before trusting a new runner configuration.
- Exit 0: executed mutants killed; 2: baseline failed; 3: survivors. Uncovered sites are not executed, so exit 0 does not prove complete coverage. Compilation failures and timeouts count as kills; inspect suspicious results.
- Cover uncovered code and add meaningful assertions for survivors. Remove demonstrably dead code only after checking intended behavior. Document equivalent mutants rather than contorting code to kill them.
- Report baseline, exact command, scope, cache/coverage provenance, killed/survived/uncovered counts, and unresolved gaps. Follow project policy for generated metrics.

Maintenance: the `agents/` directory in your dotfiles checkout (see its README).
