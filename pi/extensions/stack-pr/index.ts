import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

interface StackState {
  prevBranch: string;
  prevPR: number;
  newBranch: string;
  pollTimer?: ReturnType<typeof setInterval>;
}

export default function (pi: ExtensionAPI) {
  let active: StackState | null = null;

  // Restore state on session start (in case of restart mid-monitor)
  pi.on("session_start", async (_event, ctx) => {
    // Find the last stack-pr-state entry (later entries override earlier ones)
    let lastData: { prevBranch: string; prevPR: number; newBranch: string } | null = null;
    for (const entry of ctx.sessionManager.getEntries()) {
      if (entry.type === "custom" && entry.customType === "stack-pr-state") {
        lastData = entry.data as typeof lastData;
      }
    }

    if (lastData) {
      active = {
        prevBranch: lastData.prevBranch,
        prevPR: lastData.prevPR,
        newBranch: lastData.newBranch,
      };
      // Resume monitoring
      startMonitoring(ctx);
    }
  });

  // Clean up on shutdown
  pi.on("session_shutdown", async () => {
    if (active?.pollTimer) {
      clearInterval(active.pollTimer);
    }
  });

  function startMonitoring(ctx: any) {
    if (!active) return;

    const { prevPR, prevBranch, newBranch } = active;

    ctx.ui.setStatus("stack-pr", `⏳ Watching PR #${prevPR} (${prevBranch})`);

    active.pollTimer = setInterval(async () => {
      try {
        const result = await pi.exec("gh", [
          "pr",
          "view",
          String(prevPR),
          "--json",
          "state",
          "-q",
          ".state",
        ]);

        const state = result.stdout.trim();

        if (state === "MERGED") {
          if (active?.pollTimer) {
            clearInterval(active.pollTimer);
            active.pollTimer = undefined;
          }

          ctx.ui.setStatus("stack-pr", `✅ PR #${prevPR} merged!`);
          ctx.ui.notify(
            `PR #${prevPR} (${prevBranch}) has been merged! Run /stack-pr-rebase to rebase ${newBranch} onto main.`,
            "info"
          );

          // Send a message into the conversation so the LLM knows
          pi.sendMessage(
            {
              customType: "stack-pr-merged",
              content: `🎉 PR #${prevPR} (\`${prevBranch}\`) has been merged into main. When you're ready, run \`/stack-pr-rebase\` to rebase \`${newBranch}\` onto main.`,
              display: true,
              details: { prevPR, prevBranch, newBranch },
            },
            { triggerTurn: false, deliverAs: "nextTurn" }
          );
        } else if (state === "CLOSED") {
          if (active?.pollTimer) {
            clearInterval(active.pollTimer);
            active.pollTimer = undefined;
          }
          ctx.ui.setStatus("stack-pr", `❌ PR #${prevPR} closed`);
          ctx.ui.notify(
            `PR #${prevPR} (${prevBranch}) was closed without merging.`,
            "warning"
          );
          active = null;
        }
      } catch {
        // gh CLI error — might be transient, keep polling
      }
    }, 30_000);
  }

  // /stack-pr [new-branch-name] — start stacking
  pi.registerCommand("stack-pr", {
    description:
      "Stack a new branch on top of the current PR. Monitors the PR and helps rebase when it merges.",
    handler: async (args, ctx) => {
      // Check if already monitoring
      if (active) {
        ctx.ui.notify(
          `Already stacking: ${active.newBranch} on top of PR #${active.prevPR} (${active.prevBranch}). Use /stack-pr-status to check progress or /stack-pr-cancel to stop.`,
          "warning"
        );
        return;
      }

      // Get current branch
      const branchResult = await pi.exec("git", [
        "branch",
        "--show-current",
      ]);
      const prevBranch = branchResult.stdout.trim();

      if (!prevBranch) {
        ctx.ui.notify(
          "Not on a named branch (detached HEAD?). Checkout a branch first.",
          "error"
        );
        return;
      }

      // Check for open PR
      let prevPR: number;
      try {
        const prResult = await pi.exec("gh", [
          "pr",
          "view",
          prevBranch,
          "--json",
          "number",
          "-q",
          ".number",
        ]);
        const num = parseInt(prResult.stdout.trim(), 10);
        if (isNaN(num)) {
          ctx.ui.notify(
            `No open PR found for branch \`${prevBranch}\`. Open a PR first.`,
            "error"
          );
          return;
        }
        prevPR = num;
      } catch {
        ctx.ui.notify(
          `No open PR found for branch \`${prevBranch}\`. Open a PR first.`,
          "error"
        );
        return;
      }

      // Get new branch name
      let newBranch = args?.trim();
      if (!newBranch) {
        const input = await ctx.ui.input(
          "New branch name:",
          "feature/next-thing"
        );
        if (!input) {
          ctx.ui.notify("Cancelled.", "info");
          return;
        }
        newBranch = input.trim();
      }

      if (!newBranch) {
        ctx.ui.notify("Branch name cannot be empty.", "error");
        return;
      }

      // Create the new branch from current HEAD
      const createResult = await pi.exec("git", [
        "checkout",
        "-b",
        newBranch,
      ]);
      if (createResult.code !== 0) {
        ctx.ui.notify(
          `Failed to create branch: ${createResult.stderr.trim()}`,
          "error"
        );
        return;
      }

      // Set state
      active = { prevBranch, prevPR, newBranch };

      // Persist state for session recovery
      pi.appendEntry("stack-pr-state", { prevBranch, prevPR, newBranch });

      ctx.ui.notify(
        `Created branch \`${newBranch}\` from \`${prevBranch}\`. Monitoring PR #${prevPR}...`,
        "info"
      );

      // Start background monitoring
      startMonitoring(ctx);
    },
  });

  // /stack-pr-rebase — rebase onto main after PR merges
  pi.registerCommand("stack-pr-rebase", {
    description:
      "Rebase the stacked branch onto main after the previous PR merged.",
    handler: async (_args, ctx) => {
      if (!active) {
        ctx.ui.notify("No active stack. Run /stack-pr first.", "error");
        return;
      }

      const { prevBranch, prevPR, newBranch } = active;

      // Check the PR actually merged
      try {
        const stateResult = await pi.exec("gh", [
          "pr",
          "view",
          String(prevPR),
          "--json",
          "state",
          "-q",
          ".state",
        ]);
        const state = stateResult.stdout.trim();
        if (state !== "MERGED") {
          ctx.ui.notify(
            `PR #${prevPR} hasn't merged yet (state: ${state}). Wait for it to merge first.`,
            "warning"
          );
          return;
        }
      } catch {
        ctx.ui.notify(
          "Failed to check PR status. Make sure `gh` CLI is working.",
          "error"
        );
        return;
      }

      // Check for uncommitted changes
      const statusResult = await pi.exec("git", ["status", "--porcelain"]);
      const hasUncommitted = statusResult.stdout.trim().length > 0;

      if (hasUncommitted) {
        const proceed = await ctx.ui.confirm(
          "Uncommitted changes",
          "You have uncommitted changes. They may be lost during rebase. Continue?"
        );
        if (!proceed) {
          ctx.ui.notify("Rebase cancelled. Commit or stash your changes first.", "info");
          return;
        }
      }

      // Confirm
      const currentBranch = (
        await pi.exec("git", ["branch", "--show-current"])
      ).stdout.trim();
      if (currentBranch !== newBranch) {
        ctx.ui.notify(
          `Not on \`${newBranch}\` (currently on \`${currentBranch}\`). Checkout \`${newBranch}\` first.`,
          "warning"
        );
        return;
      }

      const ok = await ctx.ui.confirm(
        "Rebase onto main",
        `This will rebase \`${newBranch}\` onto \`origin/main\`, replaying commits after \`origin/${prevBranch}\`.\n\nProceed?`
      );
      if (!ok) {
        ctx.ui.notify("Rebase cancelled.", "info");
        return;
      }

      // Fetch latest main
      ctx.ui.setStatus("stack-pr", "Fetching origin/main...");
      await pi.exec("git", ["fetch", "origin", "main"]);

      // Check if there are commits on the new branch beyond prevBranch
      const logResult = await pi.exec("git", [
        "log",
        "--oneline",
        `origin/${prevBranch}..HEAD`,
      ]);
      const hasCommits = logResult.stdout.trim().length > 0;

      if (hasCommits) {
        // Use rebase --onto for committed work
        ctx.ui.setStatus("stack-pr", "Rebasing commits onto main...");
        const rebaseResult = await pi.exec("git", [
          "rebase",
          "--onto",
          "origin/main",
          `origin/${prevBranch}`,
          newBranch,
        ]);

        if (rebaseResult.code !== 0) {
          ctx.ui.setStatus("stack-pr", "⚠️ Rebase conflict");
          ctx.ui.notify(
            `Rebase conflict! Resolve conflicts and run \`git rebase --continue\`, or \`git rebase --abort\` to undo.\n\n${rebaseResult.stderr.trim()}`,
            "error"
          );
          return;
        }
      } else {
        // No commits — use diff/apply for uncommitted work
        ctx.ui.setStatus("stack-pr", "Applying changes onto main...");

        const diffResult = await pi.exec("git", [
          "diff",
          `origin/${prevBranch}..HEAD`,
        ]);

        if (diffResult.stdout.trim().length === 0) {
          // Nothing to apply — just reset to main
          await pi.exec("git", ["reset", "--hard", "origin/main"]);
        } else {
          // Save diff, reset, apply
          const { writeFileSync, unlinkSync } = await import("node:fs");
          const patchPath = "/tmp/stack-pr-patch.diff";
          writeFileSync(patchPath, diffResult.stdout);

          await pi.exec("git", ["reset", "--hard", "origin/main"]);
          const applyResult = await pi.exec("git", [
            "apply",
            patchPath,
          ]);

          try {
            unlinkSync(patchPath);
          } catch {}

          if (applyResult.code !== 0) {
            ctx.ui.setStatus("stack-pr", "⚠️ Apply failed");
            ctx.ui.notify(
              `Failed to apply patch. The patch was saved to /tmp/stack-pr-patch.diff for manual recovery.\n\n${applyResult.stderr.trim()}`,
              "error"
            );
            return;
          }
        }
      }

      // Show result
      const gitStatus = await pi.exec("git", ["status"]);
      const gitLog = await pi.exec("git", [
        "log",
        "--oneline",
        "-5",
        "origin/main..HEAD",
      ]);

      ctx.ui.setStatus("stack-pr", undefined); // clear status
      active = null;

      // Persist cleared state
      pi.appendEntry("stack-pr-state", null);

      const summary = [
        `✅ Rebased \`${newBranch}\` onto main.`,
        "",
        "**Recent commits:**",
        gitLog.stdout.trim() || "(no new commits — changes are unstaged)",
        "",
        "**Status:**",
        gitStatus.stdout.trim(),
      ].join("\n");

      ctx.ui.notify("Rebase complete! Review with `git status` and `git diff`.", "info");

      pi.sendMessage(
        {
          customType: "stack-pr-rebase",
          content: summary,
          display: true,
        },
        { triggerTurn: false, deliverAs: "nextTurn" }
      );
    },
  });

  // /stack-pr-status — check monitoring status
  pi.registerCommand("stack-pr-status", {
    description: "Show current stack-pr monitoring status.",
    handler: async (_args, ctx) => {
      if (!active) {
        ctx.ui.notify("No active stack being monitored.", "info");
        return;
      }

      try {
        const stateResult = await pi.exec("gh", [
          "pr",
          "view",
          String(active.prevPR),
          "--json",
          "state,title,url",
        ]);
        const pr = JSON.parse(stateResult.stdout.trim());
        ctx.ui.notify(
          `Monitoring PR #${active.prevPR}: "${pr.title}" (${pr.state})\n` +
            `Branch: ${active.newBranch} stacked on ${active.prevBranch}\n` +
            `URL: ${pr.url}`,
          "info"
        );
      } catch {
        ctx.ui.notify(
          `Monitoring PR #${active.prevPR} (${active.prevBranch} → ${active.newBranch}). Could not fetch PR details.`,
          "info"
        );
      }
    },
  });

  // /stack-pr-cancel — stop monitoring
  pi.registerCommand("stack-pr-cancel", {
    description: "Stop monitoring the previous PR. Does not delete branches.",
    handler: async (_args, ctx) => {
      if (!active) {
        ctx.ui.notify("No active stack to cancel.", "info");
        return;
      }

      if (active.pollTimer) {
        clearInterval(active.pollTimer);
      }

      ctx.ui.setStatus("stack-pr", undefined);
      ctx.ui.notify(
        `Stopped monitoring PR #${active.prevPR}. Branches unchanged.`,
        "info"
      );

      active = null;
      pi.appendEntry("stack-pr-state", null);
    },
  });
}
