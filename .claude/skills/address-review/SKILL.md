---
name: address-review
description: Views and addresses a GitHub pull request review. Use when asked to address or work on a GitHub pull request review.
agent: review-responder
---

Please analyze and fix the GitHub pull request review: $ARGUMENTS.

Follow these steps:

1. Use `gh pr-review review view $ARGUMENTS -R remrama/worn` to get the review details
2. Understand the requested changes described in the review
3. Search the codebase for relevant files
4. Implement the necessary changes to address all the changes requested
5. Write and run tests to verify the fix
6. Ensure code passes linting and type checking
7. Create a descriptive commit message
8. Update PR with new commit
9. Update PR title and/or description as needed
10. Reply to PR comments as needed
11. Resolve PR comments as needed