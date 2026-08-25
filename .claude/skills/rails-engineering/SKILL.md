---
name: rails-engineering
description: Engineering philosophy and workflow for Rails development in BookQ — think before generating code, prefer the simplest idiomatic Rails solution, follow existing conventions, and test before declaring done. Use for any bug fix, feature, refactor, debugging session, or code review in this codebase.
---

# Rails Engineering & AI Coding Skill

## Core Philosophy

Use AI as a coding companion, not as a replacement for engineering judgment.

Follow this workflow whenever solving development problems:

**Think → Try → Understand → Ask AI → Review → Implement**

Do not immediately generate a large solution before understanding the problem.

## 1. Understand the Problem First

Before writing code:

- Identify the actual problem.
- Understand the expected behavior.
- Identify the relevant model, controller, service, view, job, or component.
- Check existing code and conventions before introducing new patterns.
- Determine whether the issue is a bug, missing feature, design problem, test failure, or data problem.

When the problem is unclear, ask targeted questions or explain what information is missing.

## 2. Prefer the Simplest Solution

Always prefer:

- Existing Rails conventions
- Existing application patterns
- Small changes
- Reusable existing methods
- Clear and readable code

Avoid unnecessary:

- Abstractions
- Helper methods
- Service objects
- Custom frameworks
- Design patterns
- Dependencies
- Complex callbacks
- Premature optimizations

Do not introduce complexity unless there is a clear reason.

## 3. Respect Existing Architecture

Before suggesting a new approach:

1. Look for an existing implementation.
2. Check how similar features are implemented.
3. Follow the project's established naming conventions.
4. Reuse existing utilities and patterns when appropriate.
5. Avoid changing architecture for a localized problem.

The goal is to make the code feel like it belongs in the existing application.

## 4. Ruby on Rails Principles

Prefer idiomatic Rails solutions.

Consider:

- ActiveRecord conventions
- Model validations
- Scopes
- Associations
- Controllers
- Services only when justified
- Background jobs when appropriate
- Rails routing conventions
- Strong parameters
- Existing callbacks and concerns
- Existing authorization patterns

Do not automatically create a service object just because business logic exists.

## 5. RSpec First-Class Support

When modifying behavior:

- Check existing specs first.
- Identify the most relevant spec file.
- Add or update focused tests.
- Prefer behavior-based tests.
- Cover important edge cases.
- Avoid testing implementation details unnecessarily.

Before declaring a change complete, verify:

**Test → Understand failure → Fix → Run focused specs → Run broader specs when appropriate**

If a test fails, explain the actual cause instead of blindly modifying the test.

## 6. Debugging Workflow

When debugging:

1. Reproduce the problem.
2. Identify the failure point.
3. Trace the data flow.
4. Form a hypothesis.
5. Test the hypothesis.
6. Apply the smallest reasonable fix.
7. Add or update a regression test.

Do not randomly change multiple files hoping the problem disappears.

## 7. Code Review Mode

When reviewing code:

- First explain what the code currently does.
- Identify bugs or risks.
- Identify unnecessary complexity.
- Identify edge cases.
- Check Rails conventions.
- Check maintainability.
- Check test coverage.

Do not rewrite working code merely because another implementation is possible.

Clearly distinguish between:

**Must fix** / **Should improve** / **Optional**

## 8. When Asked for Code

Do not automatically return a huge implementation.

Start with:

1. Short explanation of the approach.
2. Files/components that need modification.
3. Why the approach fits the existing architecture.
4. Then provide the code.

For simple changes, skip unnecessary explanation and provide the focused change.

## 9. When the Proposed Approach Is Wrong

Do not blindly follow a proposed implementation.

If there is a better approach:

- Explain why.
- Show the trade-off.
- Prefer the simplest maintainable solution.

If the proposed approach is valid, do not replace it just because another approach is theoretically cleaner.

## 10. Learning Mode

Help the user understand the reasoning behind solutions.

When appropriate, explain:

- Why the code works
- Why the bug happened
- Why a particular Rails pattern is preferred
- What alternatives exist
- What trade-offs were considered

Do not hide important reasoning behind a generated block of code.

## 11. Avoid AI Overengineering

Never turn a simple problem into:

*"80 lines of code + 3 helper methods + 2 abstractions + a custom architecture"*

when a simple Rails solution would work.

Prefer:

**Simple → Clear → Tested → Maintainable**

over:

**Complex → Clever → Abstract → Difficult to understand**

## 12. Existing Code Is the Source of Truth

When working inside an existing project, prioritize:

1. Existing implementation
2. Existing tests
3. Existing conventions
4. Rails conventions
5. General best practices

Do not assume a generic tutorial or AI-generated pattern is better than the project's established approach.

## 13. Review Checklist

Before finalizing a solution, check:

- Does it actually solve the original problem?
- Is the change minimal?
- Does it follow existing project conventions?
- Is it unnecessarily complex?
- Are there edge cases?
- Are tests needed?
- Could an existing method or utility be reused?
- Does the implementation introduce unintended behavior?
- Can another developer understand it easily?

## Golden Rule

Do not let AI do the thinking before the engineer does.

Use AI to:

- Review thinking
- Challenge assumptions
- Find edge cases
- Explain concepts
- Debug
- Suggest alternatives
- Improve code
- Write code when the approach is understood

The goal is not only to produce working code.

The goal is to become a better engineer while producing working code.
