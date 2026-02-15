import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { Type } from "@sinclair/typebox";
import { Text } from "@mariozechner/pi-tui";
import { spawn } from "node:child_process";

export default function (pi: ExtensionAPI) {
  let cachedPassword: string | undefined;

  // Clear password on session end
  pi.on("session_shutdown", async () => {
    cachedPassword = undefined;
  });

  /** Masked password prompt using ctx.ui.custom() — characters shown as • */
  async function promptPassword(ctx: any, signal?: AbortSignal): Promise<string | undefined> {
    // Race the custom UI prompt against the abort signal and a timeout.
    // This prevents the prompt from hanging forever in sessions where
    // no human is present to type (e.g. sub-agents in tmux panes).
    const PROMPT_TIMEOUT_MS = 60_000; // 60s — generous for a human, catches stuck agents

    return new Promise<string | undefined>((resolve) => {
      let resolved = false;
      // Hold a reference to the TUI `done` callback so the timeout/abort
      // can dismiss the UI component — without this the prompt stays
      // rendered and blocks the session even after the promise resolves.
      let dismissUI: ((v: string | undefined) => void) | undefined;

      const finish = (v: string | undefined) => {
        if (resolved) return;
        resolved = true;
        // Always dismiss the TUI component when finishing
        dismissUI?.(v);
        resolve(v);
      };

      // Timeout fallback
      const timer = setTimeout(() => {
        finish(undefined);
      }, PROMPT_TIMEOUT_MS);

      // Abort signal fallback
      signal?.addEventListener("abort", () => {
        clearTimeout(timer);
        finish(undefined);
      });

      ctx.ui.custom<string | undefined>((tui: any, theme: any, _kb: any, done: (v: string | undefined) => void) => {
        // Capture done so timeout/abort can dismiss the UI
        dismissUI = done;

        let password = "";

        const component = new Text("", 1, 1);

        const updateDisplay = () => {
          const masked = "•".repeat(password.length);
          const label = theme.fg("accent", theme.bold("sudo password: "));
          const cursor = theme.fg("muted", "▌");
          const timeoutNote = theme.fg("dim", `  (Enter to submit, Escape to cancel — auto-cancels in ${PROMPT_TIMEOUT_MS / 1000}s)`);
          component.setText(`${label}${masked}${cursor}\n${timeoutNote}`);
        };

        updateDisplay();

        component.onKey = (data: string) => {
          if (data === "\r" || data === "\n") {
            clearTimeout(timer);
            const pw = password || undefined;
            finish(pw);
            return true;
          }
          if (data === "\x1b" || data === "\x03") { // Escape or Ctrl+C
            clearTimeout(timer);
            finish(undefined);
            return true;
          }
          if (data === "\x7f" || data === "\b") { // Backspace
            password = password.slice(0, -1);
            updateDisplay();
            return true;
          }
          // Ignore control characters
          if (data.charCodeAt(0) < 32) return true;
          password += data;
          updateDisplay();
          return true;
        };

        return component;
      }).then((v: string | undefined) => {
        clearTimeout(timer);
        finish(v);
      });
    });
  }

  /**
   * Check if this session likely has a human operator.
   * We do this by checking if `sudo -n true` works (passwordless sudo),
   * and by looking at the session name for known automation patterns.
   */
  function isLikelyAutomated(): boolean {
    const name = pi.getSessionName() ?? "";
    const automationPatterns = ["control-agent", "worker", "sub-agent", "subagent", "bot", "automation"];
    return automationPatterns.some((p) => name.toLowerCase().includes(p));
  }

  pi.registerTool({
    name: "sudo",
    label: "Sudo",
    description:
      "Run a command with sudo. The user will be prompted for their password in the TUI — you will never see it. Use this instead of `sudo` in bash when a password is required. NOTE: This tool requires human interaction for the password prompt. Do NOT call this from automated/sub-agent sessions — delegate sudo commands to the main interactive session instead.",
    parameters: Type.Object({
      command: Type.String({ description: "The command to run with sudo (without the 'sudo' prefix)" }),
      timeout: Type.Optional(Type.Number({ description: "Timeout in seconds (default 30)" })),
    }),

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const { command, timeout = 30 } = params;

      // Block destructive commands
      const destructive = ["rm -rf /", "mkfs", "dd if=", ":(){:|:&};:"];
      for (const pattern of destructive) {
        if (command.includes(pattern)) {
          return {
            content: [{ type: "text", text: `Blocked: destructive command pattern detected (${pattern})` }],
            isError: true,
          };
        }
      }

      // Reject if this looks like an automated session (no human to type password)
      if (isLikelyAutomated() && !cachedPassword) {
        return {
          content: [{
            type: "text",
            text: "Cannot use sudo from an automated/sub-agent session — no human to enter the password. "
              + "Delegate this command to the main interactive session using send_to_session.",
          }],
          isError: true,
        };
      }

      // Show the command and ask user to approve before running
      if (ctx.hasUI) {
        const approved = await ctx.ui.confirm(
          "sudo",
          `Run with sudo?\n\n  $ ${command}`,
          { signal }
        );
        if (!approved) {
          return {
            content: [{ type: "text", text: "User rejected the sudo command." }],
            isError: true,
          };
        }
      }

      // Prompt user for password if not cached (TUI-only, agent never sees it)
      if (!cachedPassword) {
        if (!ctx.hasUI) {
          return {
            content: [{ type: "text", text: "Cannot prompt for sudo password in non-interactive mode." }],
            isError: true,
          };
        }
        const pw = await promptPassword(ctx, signal);
        if (!pw) {
          return {
            content: [{ type: "text", text: "Sudo cancelled — no password provided or prompt timed out." }],
            isError: true,
          };
        }
        cachedPassword = pw;
      }

      // Run the command with sudo -S (read password from stdin)
      return new Promise((resolve) => {
        const child = spawn("sudo", ["-S", "bash", "-c", command], {
          stdio: ["pipe", "pipe", "pipe"],
        });

        let stdout = "";
        let stderr = "";

        child.stdin.write(cachedPassword + "\n");
        child.stdin.end();

        child.stdout.on("data", (data: Buffer) => {
          stdout += data.toString();
        });
        child.stderr.on("data", (data: Buffer) => {
          // Filter out the "[sudo] password for..." prompt
          const line = data.toString();
          if (!line.includes("[sudo] password for") && !line.includes("Password:")) {
            stderr += line;
          }
        });

        const timer = setTimeout(() => {
          child.kill("SIGTERM");
          resolve({
            content: [{ type: "text", text: `Command timed out after ${timeout}s` }],
            isError: true,
          });
        }, timeout * 1000);

        signal?.addEventListener("abort", () => {
          child.kill("SIGTERM");
          clearTimeout(timer);
        });

        child.on("close", (code) => {
          clearTimeout(timer);
          // If auth failed, clear cache
          if (stderr.includes("incorrect password") || stderr.includes("Sorry, try again")) {
            cachedPassword = undefined;
            resolve({
              content: [{ type: "text", text: "Incorrect sudo password (cleared cache). Try again." }],
              isError: true,
            });
            return;
          }

          let output = "";
          if (stdout) output += stdout;
          if (stderr) output += (output ? "\n" : "") + stderr;
          if (!output) output = `(no output, exit code ${code})`;

          resolve({
            content: [{ type: "text", text: output }],
            details: { exitCode: code },
            isError: code !== 0,
          });
        });
      });
    },
  });
}
