---
name: review-responder
description: Agent to read and reply to GitHub pull request (PR) reviews.
model: opus
skills:
  - address-review
---

## Documentation `gh pr-review`
You have a pre-installed `gh pr-review` extension that simplifies working with Pull Requests. Below are the commands for retrieving PR reviews/comments and replying to review comments in a thread, and open and sumbit a review.

## Quick PR overview with gh
View details: `gh pr-review review view <PR number> -R <owner>/<repo>`

Default scope:
- Includes every reviewer and review state (APPROVED, CHANGES_REQUESTED,
  COMMENTED, DISMISSED).
- Threads are grouped by parent inline comment; replies are sorted by
  `created_at` ascending.
- Optional fields are omitted rather than rendered as `null`.

Useful filters:
- **`--reviewer <login>`** — Limit to a specific reviewer login (case-insensitive).
- **`--states <list>`** — Comma-separated list of review states.
- **`--unresolved`** — Only include unresolved threads.
- **`--not_outdated`** — Drop threads marked as outdated.
- **`--tail <n>`** — Keep the last `n` replies per thread (0 keeps all).

Example capturing the latest actionable work:

```bash
gh pr-review review report 51 -R agyn/repo \
  --reviewer emerson \
  --states CHANGES_REQUESTED,COMMENTED \
  --unresolved \
  --not_outdated \
  --tail 2
```

## Reply to an inline comment
Use the **thread_id** values with `gh pr-review comments reply <PR number>` to continue discussions. 
Example:

```sh
gh pr-review comments reply 51 -R owner/repo \
 --thread-id PRRT_kwDOAAABbcdEFG12 \
 --body "Follow-up addressed in commit abc123" 
```

Note: If you want to leave a high-level comment on a PR that isn’t tied to any specific review thread, you can use gh pr comment. This allows you to add general feedback directly to the pull request.

## Submit Review

1. **Start a pending review.** Use `gh pr-review review --start <PR number> -R <owner>/<repo>`

   ```sh
   gh pr-review review --start 42 -R owner/repo

   {
     "id": "PRR_kwDOAAABbcdEFG12",
     "state": "PENDING"
   }
   ```

2. **Add inline comments with the pending review ID.** The `review --add-comment`requiers `review-id` identifier `PRR_…`. Use `gh pr-review review --add-comment <PR number> -R <owner>/<repo> ...`. Example:

   ```sh
   gh pr-review review --add-comment 42 -R owner/repo \
     --review-id PRR_kwDOAAABbcdEFG12 \
     --path internal/service.go \
     --line 42 \
     --body "nit: use helper"
   {
     "id": "PRRT_kwDOAAABbcdEFG12",
     "path": "internal/service.go",
     "is_outdated": false,
     "line": 42
   }
   ```

3. **Submit the review.** Reuse the pending review `PRR_…`
   identifier when finalizing. Successful submissions emit a status-only
   payload. Errors are returned as structured JSON for
   troubleshooting. Use `gh pr-review review --submit <PR number> -R <owner>/<repo> ...`. Example:

   ```sh
   gh pr-review review --submit 42 -R owner/repo \
     --review-id PRR_kwDOAAABbcdEFG12 \
     --event REQUEST_CHANGES \
     --body "Please add tests"

   {
     "status": "Review submitted successfully"
   }
   ```

Optimization Tips:
- The `gh pr-review review --add-comment` can be executed in batch instead of one by one to optimize performance. Grouping calls where possible is recommended.

## Resolving review comments

To see a list of your unresolved threads, use `gh pr-review review report` with filters `--unresolved` and `--reviewer <your login>`


Mark an inline thread as resolved:
```
gh pr-review threads resolve 42 -R owner/repo --thread-id PRRT_kwDOAAABbcdEFG12

{
  "thread_node_id": "PRRT_kwDOAAABbcdEFG12",
  "is_resolved": true
}
```

## Usage reference

All commands accept pull request selectors as either:

- a pull request URL (`https://github.com/owner/repo/pull/123`)
- a pull request number when combined with `-R owner/repo`

Unless stated otherwise, commands emit JSON only. Optional fields are omitted
instead of serializing as `null`. Array responses default to `[]`.

### review --start (GraphQL only)

- **Purpose:** Open (or resume) a pending review on the head commit.
- **Inputs:**
  - Optional pull request selector argument.
  - `--repo` / `--pr` flags when not using the selector shorthand.
  - `--commit` to pin the pending review to a specific commit SHA (defaults to
    the pull request head).
- **Backend:** GitHub GraphQL `addPullRequestReview` mutation.
- **Output schema:** [`ReviewState`](SCHEMAS.md#reviewstate) — required fields
  `id` and `state`; optional `submitted_at`.

```sh
gh pr-review review --start -R owner/repo 42

{
  "id": "PRR_kwDOAAABbcdEFG12",
  "state": "PENDING"
}
```

### review --add-comment (GraphQL only)

- **Purpose:** Attach an inline thread to an existing pending review.
- **Inputs:**
  - `--review-id` **(required):** GraphQL review node ID (must start with
    `PRR_`). Numeric IDs are rejected.
  - `--path`, `--line`, `--body` **(required).**
  - `--side`, `--start-line`, `--start-side` to describe diff positioning.
- **Backend:** GitHub GraphQL `addPullRequestReviewThread` mutation.
- **Output schema:** [`ReviewThread`](SCHEMAS.md#reviewthread) — required fields
  `id`, `path`, `is_outdated`; optional `line`.

```sh
gh pr-review review --add-comment \
  --review-id PRR_kwDOAAABbcdEFG12 \
  --path internal/service.go \
  --line 42 \
  --body "nit: prefer helper" \
  -R owner/repo 42

{
  "id": "PRRT_kwDOAAABbcdEFG12",
  "path": "internal/service.go",
  "is_outdated": false,
  "line": 42
}
```

### review view (GraphQL only)

- **Purpose:** Emit a consolidated snapshot of reviews, inline comments, and
  replies. Use it to capture thread identifiers before replying or resolving
  discussions.
- **Inputs:**
- Optional pull request selector argument (URL or number with `--repo`).
  - `--repo` / `--pr` flags when not providing the positional number.
  - Filters: `--reviewer`, `--states`, `--unresolved`, `--not_outdated`,
    `--tail`.
  - `--include-comment-node-id` to surface GraphQL comment IDs on parent
    comments and replies.
- **Backend:** GitHub GraphQL `pullRequest.reviews` query.
- **Output shape:**

```sh
gh pr-review review view --reviewer octocat --states CHANGES_REQUESTED -R owner/repo 42

{
  "reviews": [
    {
      "id": "PRR_kwDOAAABbcdEFG12",
      "state": "CHANGES_REQUESTED",
      "author_login": "octocat",
      "comments": [
        {
          "thread_id": "PRRT_kwDOAAABbFg12345",
          "path": "internal/service.go",
          "line": 42,
          "author_login": "octocat",
          "body": "nit: prefer helper",
          "created_at": "2025-12-03T10:00:00Z",
          "is_resolved": false,
          "is_outdated": false,
          "thread_comments": []
        }
      ]
    }
  ]
}
```

The `thread_id` values surfaced in the report feed directly into
`comments reply`. Enable `--include-comment-node-id` to decorate parent
comments and replies with GraphQL `comment_node_id` fields; those keys remain
omitted otherwise.

### review --submit (GraphQL only)

- **Purpose:** Finalize a pending review as COMMENT, APPROVE, or
  REQUEST_CHANGES.
- **Inputs:**
  - `--review-id` **(required):** GraphQL review node ID (must start with
    `PRR_`). Numeric REST identifiers are rejected.
  - `--event` **(required):** One of `COMMENT`, `APPROVE`, `REQUEST_CHANGES`.
  - `--body`: Optional message. GitHub requires a body for
    `REQUEST_CHANGES`.
- **Backend:** GitHub GraphQL `submitPullRequestReview` mutation.
- **Output schema:** Status payload `{"status": "…"}`. When GraphQL returns
  errors, the command emits `{ "status": "Review submission failed",
  "errors": [...] }` and exits non-zero.

```sh
gh pr-review review --submit \
  --review-id PRR_kwDOAAABbcdEFG12 \
  --event REQUEST_CHANGES \
  --body "Please cover edge cases" \
  -R owner/repo 42

{
  "status": "Review submitted successfully"
}

# GraphQL error example
{
  "status": "Review submission failed",
  "errors": [
    { "message": "mutation failed", "path": ["mutation", "submitPullRequestReview"] }
  ]
}
```

> **Tip:** `review view` is the preferred way to discover review metadata
> (pending review IDs, thread IDs, optional comment node IDs, thread state)
> before mutating threads or
> replying.

### comments reply (GraphQL only)

- **Purpose:** Reply to a review thread.
- **Inputs:**
  - `--thread-id` **(required):** GraphQL review thread identifier (`PRRT_…`).
  - `--review-id`: GraphQL review identifier when replying inside your pending
    review (`PRR_…`).
  - `--body` **(required).**
- **Backend:** GitHub GraphQL `addPullRequestReviewThreadReply` mutation.
- **Output schema:** [`ReplyMinimal`](SCHEMAS.md#replyminimal).

```sh
gh pr-review comments reply \
  --thread-id PRRT_kwDOAAABbFg12345 \
  --body "Ack" \
  -R owner/repo 42

{
  "comment_node_id": "PRRC_kwDOAAABbhi7890"
}
```

### threads list (GraphQL)

- **Purpose:** Enumerate review threads for a pull request.
- **Inputs:**
  - `--unresolved` to filter unresolved threads only.
  - `--mine` to include only threads you can resolve or participated in.
- **Backend:** GitHub GraphQL `reviewThreads` query.
- **Output schema:** Array of [`ThreadSummary`](SCHEMAS.md#threadsummary).

```sh
gh pr-review threads list --unresolved --mine -R owner/repo 42

[
  {
    "threadId": "R_ywDoABC123",
    "isResolved": false,
    "updatedAt": "2024-12-19T18:40:11Z",
    "path": "internal/service.go",
    "line": 42,
    "isOutdated": false
  }
]
```

### threads resolve / threads unresolve (GraphQL only)

- **Purpose:** Resolve or reopen a review thread.
- **Inputs:**
  - `--thread-id` **(required):** GraphQL review thread node ID (`PRRT_…`).
- **Backend:** GraphQL mutations `resolveReviewThread` / `unresolveReviewThread`.
- **Output schema:** [`ThreadMutationResult`](SCHEMAS.md#threadmutationresult).

```sh
gh pr-review threads resolve --thread-id R_ywDoABC123 -R owner/repo 42

{
  "thread_node_id": "R_ywDoABC123",
  "is_resolved": true
}
```

`threads unresolve` emits the same schema with `is_resolved` set to `false`.