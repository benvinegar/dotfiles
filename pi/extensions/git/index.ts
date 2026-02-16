import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Persistent branch + dirty state in footer
  async function updateStatus(ctx: any) {
    try {
      const branch = (await pi.exec("git", ["branch", "--show-current"])).stdout.trim();
      if (!branch) return;

      const status = (await pi.exec("git", ["status", "--porcelain"])).stdout.trim();
      const lines = status ? status.split("\n") : [];
      const dirty = lines.length;

      const label = dirty > 0 ? `⎇ ${branch} • ${dirty} changed` : `⎇ ${branch}`;
      ctx.ui.setStatus("git", label);
    } catch {
      // not a git repo, clear
      ctx.ui.setStatus("git", undefined);
    }
  }

  pi.on("session_start", async (_event, ctx) => updateStatus(ctx));
  pi.on("turn_end", async (_event, ctx) => updateStatus(ctx));

  // Destructive commands that need confirmation
  const DANGEROUS = [
    /^reset\s+--hard/,
    /^push\s+.*--force/,
    /^push\s+.*-f(\s|$)/,
    /^clean\s+.*-f/,
    /^checkout\s+\.$/,
  ];

  pi.registerCommand("git", {
    description: "Run git commands without leaving pi. e.g. /git status, /git co -b new-branch",
    handler: async (args, ctx) => {
      const raw = (args ?? "").trim();

      if (!raw) {
        // No args → git status
        const result = await pi.exec("git", ["status", "--short", "--branch"]);
        ctx.ui.notify(result.stdout.trim() || "Nothing to report.", "info");
        await updateStatus(ctx);
        return;
      }

      // Safety check
      for (const pattern of DANGEROUS) {
        if (pattern.test(raw)) {
          const ok = await ctx.ui.confirm("Destructive git command", `Run \`git ${raw}\`?`);
          if (!ok) {
            ctx.ui.notify("Cancelled.", "info");
            return;
          }
          break;
        }
      }

      // Interactive branch picker: /git co with no target
      if (/^(checkout|co|switch)$/.test(raw)) {
        const result = await pi.exec("git", [
          "branch",
          "--sort=-committerdate",
          "--format=%(refname:short)",
        ]);
        const branches = result.stdout.trim().split("\n").filter(Boolean);
        if (branches.length === 0) {
          ctx.ui.notify("No branches found.", "info");
          return;
        }
        const choice = await ctx.ui.select("Switch branch:", branches);
        if (choice === undefined) {
          ctx.ui.notify("Cancelled.", "info");
          return;
        }
        const co = await pi.exec("git", ["checkout", branches[choice]]);
        ctx.ui.notify(
          co.stderr.trim() || co.stdout.trim() || `Switched to ${branches[choice]}`,
          co.code === 0 ? "info" : "error"
        );
        await updateStatus(ctx);
        return;
      }

      // Commit with editor: /git commit (no -m)
      if (/^commit$/.test(raw) || /^commit\s+(?!.*-m)/.test(raw)) {
        const diff = await pi.exec("git", ["diff", "--cached", "--stat"]);
        const staged = diff.stdout.trim();
        if (!staged) {
          ctx.ui.notify("Nothing staged. Use `git add` first.", "warning");
          return;
        }

        const msg = await ctx.ui.editor(
          "Commit message:",
          "",
        );
        if (!msg || !msg.trim()) {
          ctx.ui.notify("Empty message, commit cancelled.", "info");
          return;
        }

        const result = await pi.exec("git", ["commit", "-m", msg.trim()]);
        ctx.ui.notify(
          result.stdout.trim() || result.stderr.trim(),
          result.code === 0 ? "info" : "error"
        );
        await updateStatus(ctx);
        return;
      }

      // Passthrough — split args respecting quotes
      const gitArgs = shellSplit(raw);
      const result = await pi.exec("git", gitArgs);
      const output = [result.stdout, result.stderr].filter(s => s.trim()).join("\n").trim();

      if (output) {
        ctx.ui.notify(output, result.code === 0 ? "info" : "error");
      } else {
        ctx.ui.notify(result.code === 0 ? "Done." : `Exit code ${result.code}`, result.code === 0 ? "info" : "error");
      }

      await updateStatus(ctx);
    },
  });
}

/** Naive shell-style arg splitting (handles single/double quotes) */
function shellSplit(s: string): string[] {
  const args: string[] = [];
  let current = "";
  let quote: string | null = null;

  for (let i = 0; i < s.length; i++) {
    const c = s[i];
    if (quote) {
      if (c === quote) {
        quote = null;
      } else {
        current += c;
      }
    } else if (c === '"' || c === "'") {
      quote = c;
    } else if (c === " " || c === "\t") {
      if (current) {
        args.push(current);
        current = "";
      }
    } else {
      current += c;
    }
  }
  if (current) args.push(current);
  return args;
}
