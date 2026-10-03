import type { Plugin } from "@opencode-ai/plugin"
import { execSync } from "child_process"
import { existsSync, readFileSync } from "fs"
import { tmpdir } from "os"
import { join } from "path"

function getAcpdToken(): string | null {
  const uid = typeof process.getuid === "function" ? process.getuid() : (process.env.UID || "1000")
  const homeDir = process.env.HOME || (process.env.USER ? `/home/${process.env.USER}` : tmpdir())
  const xdgRuntime = process.env.XDG_RUNTIME_DIR || `/run/user/${uid}`
  const candidates = [
    join(xdgRuntime, "acpd", "token"),
    join(tmpdir(), `acpd-${uid}`, "token"),
    join(homeDir, ".cache", "acpd", "token"),
  ]
  for (const tokenPath of candidates) {
    try {
      if (existsSync(tokenPath)) {
        return readFileSync(tokenPath, "utf8").trim()
      }
    } catch {}
  }
  return null
}

function getAcpdHeaders(): Record<string, string> {
  const headers: Record<string, string> = { "Content-Type": "application/json" }
  const token = getAcpdToken()
  if (token) {
    headers["Authorization"] = `Bearer ${token}`
  }
  return headers
}

function getActiveTmuxPane(): string {
  let pane = process.env.TMUX_PANE ?? ""
  if (!pane) {
    try {
      pane = execSync('tmux display-message -p "#{pane_id}"', { stdio: "pipe" }).toString().trim()
    } catch {}
  }
  return pane
}

/**
 * Thin Client Plugin that:
 * - Forwards OpenCode state events to the ACP daemon (acpd) running on port 4040.
 */
export const NotifyIdlePlugin: Plugin = async ({ $ }) => {
  const sendAcpState = async (state: string, message: string | null = null) => {
    const pane = getActiveTmuxPane()
    if (!pane) return
    try {
      await fetch("http://127.0.0.1:4040/api/status", {
        method: "POST",
        headers: getAcpdHeaders(),
        body: JSON.stringify({ pane_id: pane, state, message }),
      })
    } catch {
      // Ignore failures if the acpd daemon is not running
    }
  }

  const setAiAgentTitle = (title: string | null) => {
    const pane = getActiveTmuxPane()
    if (!pane) return
    try {
      if (title && title.trim().length > 0) {
        const cleanTitle = title.trim().replace(/["\\$`]/g, "").slice(0, 80)
        execSync(`tmux set-option -w -t "${pane}" @ai_agent_title "${cleanTitle}"`, { stdio: "ignore" })
      } else {
        execSync(`tmux set-option -w -u -t "${pane}" @ai_agent_title`, { stdio: "ignore" })
      }
    } catch {}
  }

  process.on("exit", () => {
    try {
      setAiAgentTitle(null)
      const pane = getActiveTmuxPane()
      if (!pane) return
      const token = getAcpdToken()
      const authHeader = token ? `-H "Authorization: Bearer ${token}"` : ""
      execSync(`curl -s -X POST http://127.0.0.1:4040/api/status ${authHeader} -H "Content-Type: application/json" -d '{"pane_id":"${pane}","state":"closed"}'`);
    } catch {
      // Ignore errors on exit
    }
  });

  // Handle Ctrl+C properly to trigger exit
  process.on("SIGINT", () => {
    process.exit(0);
  });

  let waitingPermission = false

  return {
    "event": async ({ event }) => {
      const evtType = (event as any)?.type ?? "unknown"

      if (evtType === "session.created" || evtType === "session.updated") {
        const title = (event as any)?.properties?.info?.title
        if (title) {
          setAiAgentTitle(title)
        }
        return
      }

      if (evtType === "session.deleted") {
        setAiAgentTitle(null)
        return
      }

      if (evtType === "permission.asked") {
        waitingPermission = true
        await sendAcpState("permission")
        return
      }

      if (evtType === "permission.replied") {
        waitingPermission = false
        return
      }

      if (evtType !== "session.status") return

      const properties = (event as any)?.properties

      const statusType: string = properties?.status?.type ?? "unknown"

      // Keep permission indicator visible while waiting for user reply.
      if (waitingPermission && statusType === "busy") return
      
      if (statusType === "idle") {
        await sendAcpState("idle")
      } else if (statusType === "busy") {
        await sendAcpState("working")
      } else if (statusType === "retry") {
        await sendAcpState("error")
      }
    },

    "tool.execute.before": async (input) => {
      const toolName = (input as Record<string, any>)?.tool ?? "tool"
      if (toolName === "question") {
        await sendAcpState("awaiting_input")
      } else {
        await sendAcpState("working")
      }
    },

    "permission.ask": async (input) => {
      await sendAcpState("permission")
    },

    "permission.asked": async (input) => {
      await sendAcpState("permission")
    },
  }
}
