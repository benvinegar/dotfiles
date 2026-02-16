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

      const expanded = expandAliases(shellSplit(raw));
      const expandedStr = expanded.join(" ");

      // Safety check (on expanded form so aliases like `co .` get caught)
      for (const pattern of DANGEROUS) {
        if (pattern.test(expandedStr)) {
          const ok = await ctx.ui.confirm("Destructive git command", `Run \`git ${expandedStr}\`?`);
          if (!ok) {
            ctx.ui.notify("Cancelled.", "info");
            return;
          }
          break;
        }
      }

      // Interactive branch picker: /git co (or checkout/switch) with no target
      if (expanded.length === 1 && /^(checkout|switch)$/.test(expanded[0])) {
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

      // Commit with editor: /git commit or /git ci (no -m)
      if (expanded[0] === "commit" && !expanded.includes("-m")) {
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

      // Passthrough
      const result = await pi.exec("git", expanded);
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

const ALIASES: Record<string, string[]> = {
  co: ["checkout"],
  ci: ["commit"],
  br: ["branch"],
  st: ["status"],
  sw: ["switch"],
  cp: ["cherry-pick"],
  lg: ["log", "--oneline", "--graph", "--decorate"],
  s: ["status", "--short", "--branch"],
  d: ["diff"],
  ds: ["diff", "--staged"],
  ap: ["add", "-p"],
  unstage: ["reset", "HEAD", "--"],
  amend: ["commit", "--amend", "--no-edit"],
};

function expandAliases(args: string[]): string[] {
  if (args.length === 0) return args;
  const alias = ALIASES[args[0]];
  if (alias) return [...alias, ...args.slice(1)];
  return args;
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
