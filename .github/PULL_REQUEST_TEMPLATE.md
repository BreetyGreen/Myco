<!-- Thanks for contributing! Fill this in so review is quick. -->

## What does this PR do?

<!-- One or two sentences. -->

## Type of change

- [ ] Path update for an existing agent (most valuable here)
- [ ] New agent support
- [ ] Skill content / docs improvement
- [ ] Script (`distribute.py`) change
- [ ] Other

## If this touches agent paths

- Agent + version:
- OS tested on:
- How you verified the path actually works:
  <!-- e.g. ran distribute.py, dropped SKILL.md, the agent picked it up -->

## Checklist

- [ ] I updated the compatibility table in `README.md` **and** `README.zh-CN.md` if paths changed
- [ ] I ran `python3 scripts/distribute.py --src ./skill --dest . --dry-run` and it succeeded
- [ ] `SKILL.md` frontmatter still has a `name:` and `description:`
- [ ] Docs reflect the change (INSTALL.md / SKILL.md as needed)
