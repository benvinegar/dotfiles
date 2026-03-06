import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { spawnSync } from "node:child_process";

const STATUS = {
  idle: "pi:idle",
  busy: "pi:busy",
  offline: "pi:offline",
} as const;

export default function (pi: ExtensionAPI) {
  const paneId = process.env.TMUX_PANE;
  if (!paneId) return; // Not running inside tmux.

  const setPaneTitle = (title: string) => {
    try {
      spawnSync("tmux", ["select-pane", "-t", paneId, "-T", title], {
        stdio: "ignore",
        timeout: 1_000,
      });
    } catch {
      // Best effort only.
    }
  };

  pi.on("session_start", async () => {
    setPaneTitle(STATUS.idle);
  });

  pi.on("session_switch", async () => {
    setPaneTitle(STATUS.idle);
  });

  pi.on("agent_start", async () => {
    setPaneTitle(STATUS.busy);
  });

  pi.on("agent_end", async (_event, ctx) => {
    setPaneTitle(ctx.hasPendingMessages() ? STATUS.busy : STATUS.idle);
  });

  pi.on("session_shutdown", async () => {
    setPaneTitle(STATUS.offline);
  });
}
