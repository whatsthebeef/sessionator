# ATF fix globs

Read this when: a "Fix ATF on <env>" glob. It adds to `.claude/agents/orchestrator.md`; where the two differ, this guide wins for the run.

A glob whose plan has an `## ATF fix rules` section (slopmux opens "Fix ATF on <env>" when an ATF build of the base fails; the attachment `ATF failures (<env>)` lists the failing tests, the build log link and the suspect globs) is a normal glob run with those rules on top. Read the attachment in Phase 1 and give the investigator and implementer the rules; they are not optional.

1. Before any change, classify each failing test as *outdated test* (changed on purpose, in a merged glob you can name), *regression* or *flaky / environmental*, and write the table under `## Decisions` of the record.
2. Never delete, skip or loosen a test, widen a timeout to mask a failure, or change what a test checks. An outdated test is updated to assert the same behaviour; the record names the glob that changed it.
3. A regression whose cause is not clear and small is not fixed here: leave the test alone and `raise_question` naming the suspect glob. Flaky or environmental: rerun once; if it fails again, report the evidence and change nothing.
4. The change_reviewer gets the rules and checks every test diff against them.
