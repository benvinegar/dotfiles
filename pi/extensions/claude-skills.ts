/**
 * Claude Skills Extension
 *
 * Discovers Claude/Cursor skill files from:
 * - Project: .agents/skills/<name>/SKILL.md
 * - User:    ~/.claude/skills/<name>/SKILL.md
 *
 * Registers each skill as /skill-<name> command. When invoked, the skill's
 * SKILL.md content (plus any sibling .md files) is sent as a user message
 * to the agent.
 *
 * Usage:
 *   /skill-commit           # run the "commit" skill
 *   /skill-deslop           # run the "deslop" skill
 *   /skill-write-like-ben   # run a user-level skill
 */

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import fs from "node:fs";
import path from "node:path";
import os from "node:os";

interface Skill {
	name: string;
	description: string;
	directory: string;
	source: "project" | "user";
}

function parseSkillFrontmatter(content: string): { name?: string; description?: string; body: string } {
	const match = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
	if (!match) return { body: content };

	const frontmatter = match[1];
	const body = match[2];
	let name: string | undefined;
	let description: string | undefined;

	for (const line of frontmatter.split("\n")) {
		const nameMatch = line.match(/^name:\s*(.+)/);
		if (nameMatch) name = nameMatch[1].trim();
		const descMatch = line.match(/^description:\s*(.+)/);
		if (descMatch) description = descMatch[1].trim();
	}

	return { name, description, body };
}

function discoverSkills(cwd: string): Skill[] {
	const skills: Skill[] = [];
	const seen = new Set<string>();

	const dirs = [
		{ base: path.join(cwd, ".agents", "skills"), source: "project" as const },
		{ base: path.join(os.homedir(), ".claude", "skills"), source: "user" as const },
	];

	for (const { base, source } of dirs) {
		if (!fs.existsSync(base)) continue;

		let entries: fs.Dirent[];
		try {
			entries = fs.readdirSync(base, { withFileTypes: true });
		} catch {
			continue;
		}

		for (const entry of entries) {
			if (!entry.isDirectory()) continue;

			const skillDir = path.join(base, entry.name);
			const skillFile = path.join(skillDir, "SKILL.md");
			if (!fs.existsSync(skillFile)) continue;

			const content = fs.readFileSync(skillFile, "utf-8");
			const { name, description } = parseSkillFrontmatter(content);
			const skillName = name || entry.name;

			// Project skills take precedence over user skills
			if (seen.has(skillName)) continue;
			seen.add(skillName);

			skills.push({
				name: skillName,
				description: description || `Run the "${skillName}" skill`,
				directory: skillDir,
				source,
			});
		}
	}

	return skills;
}

function loadSkillContent(skill: Skill): string {
	const skillFile = path.join(skill.directory, "SKILL.md");
	const mainContent = fs.readFileSync(skillFile, "utf-8");
	const { body } = parseSkillFrontmatter(mainContent);

	const parts = [body.trim()];

	// Load sibling .md files (e.g. phase-1-planning.md, rules/*.md)
	try {
		const siblingFiles = collectMarkdownFiles(skill.directory)
			.filter((f) => path.basename(f) !== "SKILL.md")
			.sort();

		for (const file of siblingFiles) {
			const relPath = path.relative(skill.directory, file);
			const content = fs.readFileSync(file, "utf-8").trim();
			if (content) {
				parts.push(`\n\n<!-- ${relPath} -->\n${content}`);
			}
		}
	} catch {
		// Ignore errors reading siblings
	}

	return parts.join("\n");
}

function collectMarkdownFiles(dir: string): string[] {
	const results: string[] = [];
	try {
		const entries = fs.readdirSync(dir, { withFileTypes: true });
		for (const entry of entries) {
			const full = path.join(dir, entry.name);
			if (entry.isDirectory()) {
				results.push(...collectMarkdownFiles(full));
			} else if (entry.name.endsWith(".md")) {
				results.push(full);
			}
		}
	} catch {
		// Ignore
	}
	return results;
}

export default function (pi: ExtensionAPI) {
	const cwd = process.cwd();
	const skills = discoverSkills(cwd);

	for (const skill of skills) {
		const commandName = `skill-${skill.name}`;

		pi.registerCommand(commandName, {
			description: `[${skill.source}] ${skill.description}`,
			handler: async (args, ctx) => {
				const content = loadSkillContent(skill);
				const prompt = args?.trim()
					? `${content}\n\n---\n\nAdditional instructions: ${args.trim()}`
					: content;

				pi.sendUserMessage(prompt);
			},
		});
	}

	// Also register a /skills command to list all available skills
	pi.registerCommand("skills", {
		description: "List all available Claude skills",
		handler: async (_args, ctx) => {
			if (skills.length === 0) {
				ctx.ui.notify("No skills found", "warning");
				return;
			}

			const lines = skills.map((s) => {
				const tag = s.source === "project" ? "project" : "user";
				return `  /skill-${s.name}  (${tag}) — ${s.description}`;
			});

			ctx.ui.notify(`Available skills:\n${lines.join("\n")}`, "info");
		},
	});
}
