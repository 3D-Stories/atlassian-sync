# atlassian-sync

Bidirectional sync between Markdown artifacts and Jira Cloud / Confluence Cloud. Built for the [BMAD Method](https://github.com/bmad-method/bmad) but works standalone with any project.

## What It Does

- **Push** `.md` files to Jira as Stories, Epics, or Tasks (create or update)
- **Pull** Jira state back into `.md` frontmatter (status, timestamps)
- **Bidirectional conflict resolution** with merge strategy (status always advances forward)
- **Publish Confluence pages** for sprint summaries, retrospectives, and change proposals
- **BMAD workflow integration** via shared skill files that hook into sprint-planning, create-story, dev-story, and 5 more workflows
- **Standalone CLI** for any project with Markdown files

## Prerequisites

- **Python 3.8+** (bundled API client uses only stdlib — no pip packages)
- **Node.js 18+** and **npm** (for the TypeScript sync engine)
- **Atlassian Cloud account** with:
  - A Jira project
  - A Confluence space
  - A service account API token (see [Authentication](#authentication) below)

## Authentication

This tool uses the Atlassian Cloud API via `api.atlassian.com` with Basic auth (service account email + API token).

### Required API Token Scopes

Create a service account at [admin.atlassian.com](https://admin.atlassian.com) and generate an API token with these scopes:

**Jira Platform:**
- `read:jira-work`, `write:jira-work`, `read:jira-user`, `read:me`

**Jira Software:**
- `read:board-scope:jira-software`, `read:board-scope.admin:jira-software`
- `read:sprint:jira-software`, `write:sprint:jira-software`
- `read:issue:jira-software`, `write:issue:jira-software`
- `read:epic:jira-software`, `write:epic:jira-software`

**Confluence:**
- `read:confluence-content.all`, `read:confluence-space.summary`
- `write:confluence-content`, `write:confluence-file`

### Environment Variables

Create a `.env` file in your project root (copy from `.env.example`):

```env
ATLASSIAN_SA_EMAIL=your-service-account@serviceaccount.atlassian.com
ATLASSIAN_API_TOKEN=your-api-token
ATLASSIAN_CLOUD_ID=your-cloud-id
ATLASSIAN_SITE_URL=https://your-domain.atlassian.net
JIRA_PROJECT_KEY=PROJ
CONFLUENCE_SPACE_KEY=PROJ
JIRA_BOARD_ID=1
```

Find your Cloud ID at: `https://your-domain.atlassian.net/_edge/tenant_info`

## Installation

### Option A: BMAD Project Integration

```bash
git clone https://github.com/3D-Stories/atlassian-sync.git
cd atlassian-sync
./scripts/install-bmad.sh /path/to/your-bmad-project
```

This copies:
- Skill files to `.claude/skills/bmad-atlassian-sync/`
- Sync engine to `.claude/tools/atlassian-sync/`
- `.env.atlassian.example` to your project root

Then add to your `_bmad/bmm/config.yaml`:

```yaml
atlassian_sync: enabled
jira_project_key: PROJ
jira_board_id: 1
confluence_space_key: PROJ
```

### Option B: Standalone CLI

```bash
./scripts/install-standalone.sh
atlassian-sync --help
```

### Option C: Run from Source

```bash
git clone https://github.com/3D-Stories/atlassian-sync.git
cd atlassian-sync
npm install
npx tsx src/cli.ts --help
```

## CLI Usage

```bash
# Push a story to Jira (creates issue, writes jira_key back to file)
atlassian-sync push stories/1-1-user-auth.md

# Pull latest Jira state into local file
atlassian-sync pull stories/1-1-user-auth.md

# Bidirectional sync (pull then push)
atlassian-sync sync stories/1-1-user-auth.md

# Push an epic
atlassian-sync push epics/epic-1.md --type epic
```

### Python CLI (Direct API Access)

The bundled Python CLI can be used directly for quick operations:

```bash
# Jira
python3 src/python/atlassian_cli.py jira get PROJ-42
python3 src/python/atlassian_cli.py jira create PROJ Story "Story title" "Description"
python3 src/python/atlassian_cli.py jira search "project = PROJ AND status = 'To Do'"
python3 src/python/atlassian_cli.py jira comment PROJ-42 "Implementation complete"
python3 src/python/atlassian_cli.py jira transitions PROJ-42
python3 src/python/atlassian_cli.py jira transition PROJ-42 31
python3 src/python/atlassian_cli.py jira create-sprint 1 "Sprint 1" "Sprint goal"
python3 src/python/atlassian_cli.py jira move-to-sprint 42 PROJ-1 PROJ-2

# Confluence
python3 src/python/atlassian_cli.py confluence get 12345
python3 src/python/atlassian_cli.py confluence find "Page Title"
python3 src/python/atlassian_cli.py confluence create "Page Title" body.html --parent 12345
echo "<h2>Hello</h2>" | python3 src/python/atlassian_cli.py confluence create "Title" -
```

## Frontmatter

The sync engine reads and writes YAML frontmatter in `.md` files:

```yaml
---
story_key: 1-1-user-auth
status: ready-for-dev
jira_key: PROJ-42
confluence_page_id: 12345
last_synced_at: "2026-03-16T14:30:00Z"
jira_updated_at: "2026-03-16T14:30:00Z"
---
```

## BMAD Skill Integration

After `install-bmad.sh`, these workflows automatically sync to Jira/Confluence:

| Skill | Jira Action | Confluence Action |
|---|---|---|
| `sprint-planning` | Create epics, stories, sprint | Create sprint overview page |
| `create-story` | Create Jira story | -- |
| `dev-story` | Transition In Progress / In Review | -- |
| `correct-course` | Create change-request issue | Create change proposal page |
| `retrospective` | Comment on epic | Create retrospective page |
| `sprint-status` | Pull latest statuses | Update sprint page |
| `code-review` | Comment with findings | -- |
| `create-epics-and-stories` | Create all epics + stories | -- |

All sync steps check `atlassian_sync: enabled` in config and skip silently when not configured.

## Architecture

```
src/
  python/                       # Bundled Python API client (zero external deps)
    atlassian_client.py          #   Auth, cloud-ID routing, all Jira/Confluence API calls
    atlassian_cli.py             #   CLI for direct bash usage
  atlassian-bridge.py           # JSON stdin/stdout bridge (TypeScript calls Python)
  clients/                      # TypeScript wrappers calling the bridge
  parsers/                      # .md frontmatter + sprint-status.yaml parsers
  sync/                         # Sync engine + conflict resolver + field mapper
  templates/                    # Confluence XHTML page templates
  config.ts                     # Config loader (.env + optional BMAD config.yaml)
  cli.ts                        # CLI entry point
bmad-integration/
  skills/bmad-atlassian-sync/   # BMAD shared skill files
  config/                       # Config templates for BMAD and standalone
scripts/
  install-bmad.sh               # Install into a BMAD project
  install-standalone.sh         # Install CLI standalone
tests/                          # 67 tests (vitest)
```

## Development

```bash
npm install
npm test              # Run all 67 tests
npm run test:watch    # Watch mode
npx tsc --noEmit      # Type-check
```

## License

MIT
