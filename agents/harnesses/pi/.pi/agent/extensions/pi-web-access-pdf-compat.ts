import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { existsSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import { pathToFileURL } from "node:url";

export default function (pi: ExtensionAPI) {
  pi.on("session_start", async (_event, ctx) => {
    const agentDir =
      process.env.PI_CODING_AGENT_DIR || join(homedir(), ".pi", "agent");
    const moduleDir = ["unpdf", join("pi-web-access", "node_modules", "unpdf")]
      .map((pkg) => join(agentDir, "npm", "node_modules", pkg, "dist"))
      .find(
        (dir) =>
          existsSync(join(dir, "index.mjs")) &&
          existsSync(join(dir, "pdfjs.mjs")),
      );
    if (!moduleDir) return;

    // Pi's bundled loader cannot resolve unpdf's internal self-import. [D-PI-WEB]
    // Use unpdf's supported initializer without changing installed packages.
    try {
      const [unpdf, pdfjs] = await Promise.all([
        import(pathToFileURL(join(moduleDir, "index.mjs")).href),
        import(pathToFileURL(join(moduleDir, "pdfjs.mjs")).href),
      ]);
      await unpdf.definePDFJSModule(() => Promise.resolve(pdfjs));
    } catch (error) {
      ctx.ui.notify(
        `PDF compatibility initialization failed: ${String(error)}`,
        "warning",
      );
    }
  });
}
