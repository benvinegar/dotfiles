---
name: address-pr-review
description: Fetch PR review comments, evaluate suggestions, apply fixes when valid, reply to reviewers, then commit and push.
---

# Address PR Review Comments

When activated, fetch and address pending PR review comments.

## Workflow

1. **Detect the PR** — run `gh pr view --json number -q .number` to get the PR number from the current branch. If not on a PR branch, ask the user.

2. **Fetch review comments:**
   ```bash
   gh api "repos/{owner}/{repo}/pulls/PR_NUMBER/comments" --jq '.[] | {id, path, line: (.line // .original_line), body, user: .user.login, in_reply_to_id, created_at}'
   ```

3. **Filter to pending comments:**
   - Skip comments that are replies (have `in_reply_to_id`) — those are discussion, not reviews
   - Skip comments you've already replied to — check if any reply to a comment's `id` has your login as the user
   - Get your login: `gh api user -q .login`

4. **Group by file** — address all comments on the same file together to avoid multiple commits per file

5. **For each comment, evaluate:**
   - Read the file and surrounding context
   - Is the suggestion valid and worth implementing?
   - Is it a real bug, a style nit, or an AI hallucination?
   - Common bot reviewers (greptile, sentry) sometimes suggest things that are wrong or out of scope — push back when warranted

6. **If fixing:** make the edit, then move to the next comment on that file before committing

7. **Reply to each comment** (whether you fixed it or not):
   ```bash
   gh api "repos/{owner}/{repo}/pulls/PR_NUMBER/comments/COMMENT_ID/replies" -f body="Your response"
   ```
   - If fixed: briefly describe what you changed
   - If not fixing: explain why (known limitation, out of scope, disagree with suggestion, etc.)
   - After your main response, append a small italicized attribution line that states which agent + model responded
   - Format the attribution exactly like this on a new line:
     ```html
     <sub><i>Responded by AGENT_NAME using MODEL_NAME.</i></sub>
     ```
   - Example:
     ```text
     Added a guard for undefined payloads before accessing .id, and added a regression test.

     <sub><i>Responded by dev-agent-modem-a8b7b331 using openai/gpt-5-mini.</i></sub>
     ```

8. **After all comments are addressed:** commit the changes with a descriptive message and push

## Guidelines

- Don't make a change you wouldn't make without the review comment — bot reviewers generate noise
- Group fixes into logical commits (one per file or per theme, not one per comment)
- Be concise in replies — reviewers don't want essays
- If a suggestion requires a larger refactor, say so and suggest a follow-up
