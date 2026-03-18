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

### BMAD Skill Modifications Required

After installing `atlassian-sync`, the following changes must be made to BMAD workflow skills. These are **not** done automatically by `install-bmad.sh` — they modify BMAD Method core skills and should be applied manually or via a patch.

#### bmad-sprint-planning
- **workflow.md**: Added `### Atlassian Sync` section after `### Context` in INITIALIZATION
- **workflow.md**: Added `<step n="6">` before `</workflow>` — creates Jira epics/stories/sprint, creates Confluence sprint overview page, stores `jira_sprint_id` and `confluence_page_id` in `sprint-status.yaml`

#### bmad-create-story
- **workflow.md**: Added `### Atlassian Sync` section in INITIALIZATION
- **workflow.md**: Added `<step n="7">` — creates Jira story, writes `jira_key` to story `.md` frontmatter and `sprint-status.yaml`
- **template.md**: Added YAML frontmatter block with `story_key`, `epic_num`, `story_num`, `status`, `jira_key`, `confluence_page_id` fields

#### bmad-dev-story
- **workflow.md**: Added `### Atlassian Sync` section in INITIALIZATION
- **workflow.md**: Added `<step n="2a">` — pulls latest Jira state before starting work (sync-on-start)
- **workflow.md step 4**: Added Jira transition to "In Progress" (inline check)
- **workflow.md step 9**: Added Jira transition to "In Review", comment with implementation summary, sync metadata update (inline check)

#### bmad-correct-course
- **workflow.md**: Added `### Atlassian Sync` section in INITIALIZATION
- **workflow.md step 5**: Added Jira change-request issue creation and Confluence change proposal page creation after proposal approval (inline check)

#### bmad-retrospective
- **workflow.md**: Added `### Atlassian Sync` section in INITIALIZATION
- **workflow.md**: Added `<step n="sync">` before `</workflow>` — creates Confluence retrospective page, links to sprint page, comments on Jira epic

#### bmad-sprint-status
- **workflow.md**: Added `### Atlassian Sync` section in INITIALIZATION
- **workflow.md step 2**: Added bidirectional Jira pull — fetches latest statuses for stories with `jira_key`, updates local `sprint-status.yaml` (inline check)
- **workflow.md step 4**: Added Confluence sprint page refresh with current status data (inline check)

#### bmad-code-review
- **workflow.md**: Added `### 3. Atlassian Sync` prose section — documents Jira comment with review findings and Done transition via `sync-on-complete` pattern

#### bmad-create-epics-and-stories
- **workflow.md**: Added `### 3. Atlassian Sync` prose section — documents Jira Epic/Story creation and `jira_key` writeback via `sync-on-complete` pattern

#### bmad-create-prd
- **workflow.md**: Added `### 2. Atlassian Sync` section documenting multi-page Confluence structure
- **steps-c/step-12-complete.md**: Added step 5 — asks for Confluence space URL, creates parent page with section summary table, creates child pages per PRD section (Executive Summary, Success Criteria, User Journeys, FRs, NFRs, etc.), stores `confluence_page_id` + `confluence_sections` mapping in frontmatter

#### bmad-edit-prd
- **workflow.md**: Added `### 2. Atlassian Sync` section documenting selective section update behavior
- **steps-e/step-e-04-complete.md**: Added step 3 — reads `confluence_sections` mapping, selectively updates only changed child pages, creates new child pages for added sections, archives (adds removal notice, never deletes) pages for removed sections, refreshes parent page summary table

#### bmad-validate-prd
- **workflow.md**: Added `### 2. Atlassian Sync` section documenting validation report publishing
- **steps-v/step-v-13-report-complete.md**: Added step 4 — publishes validation report as Confluence page (sibling of PRD parent), updates PRD section pages if "Fix Simpler Items" was applied

### PRD Confluence Page Structure

When `bmad-create-prd` publishes to Confluence, it creates a multi-page hierarchy:

```
Confluence Space
└── {project_name} — Product Requirements Document  (parent: summary + links)
    ├── {project_name} PRD: Executive Summary & Vision
    ├── {project_name} PRD: Success Criteria & KPIs
    ├── {project_name} PRD: User Journeys
    ├── {project_name} PRD: Domain Requirements
    ├── {project_name} PRD: Functional Requirements
    ├── {project_name} PRD: Non-Functional Requirements
    └── {project_name} — PRD Validation Report      (created by validate-prd)
```

The parent page ID and section-to-page mapping are stored in PRD frontmatter:

```yaml
---
confluence_page_id: "12345"
confluence_sections:
  executive_summary: "12346"
  success_criteria: "12347"
  user_journeys: "12348"
  functional_requirements: "12349"
  non_functional_requirements: "12350"
---
```

`bmad-edit-prd` and `bmad-validate-prd` read this mapping to update individual section pages without rewriting the entire structure.

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
