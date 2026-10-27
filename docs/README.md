# Documentation

One page per question. If you are not sure where to start, read the two rows
marked with an arrow.

## Using the toolkit

| Document | Answers |
| --- | --- |
| → [`install.md`](install.md) | How do I install it, and which system dependencies does it need? |
| → [`usage.md`](usage.md) | How do I configure a repository, run the commands and wire it into CI? |
| [`migration.md`](migration.md) | I have a legacy setup or an older version: what do I change, and what breaks? |

## Maintaining the toolkit

| Document | Answers |
| --- | --- |
| [`architecture.md`](architecture.md) | Why is it built this way, what does the render pipeline do, and which decisions were taken? |
| [`releasing.md`](releasing.md) | How is a version cut, published and verified? |
| [`dependency-policy.md`](dependency-policy.md) | Which versions are pinned, how are they updated, and why is the Mermaid CLI different? |
| [`i18n.md`](i18n.md) | How do the catalogs, the keys and the two runtimes fit together? |
| [`design/`](design/) | Design records for features that already shipped. Reasoning, not instructions. |

## Outside `docs/`

| File | For |
| --- | --- |
| [`../README.md`](../README.md) | What the project is, and the shortest path to a first PDF. |
| [`../AGENTS.md`](../AGENTS.md) | The stable rules: contract, compatibility, language policy, where to change what. |
| [`../CONTEXT.md`](../CONTEXT.md) | Current operational state and the decisions behind it. |
| [`../CHANGELOG.md`](../CHANGELOG.md) | What changed in each version. A record, not current documentation. |
| [`../CONTRIBUTING.md`](../CONTRIBUTING.md) | How to set up, test and submit a change. |
| [`../.github/SECURITY.md`](../.github/SECURITY.md) | How to report a vulnerability. |
| [`../.agents/skills/`](../.agents/skills/) | Operating skills for agents, versioned and reviewed in pull requests. |

Two rules apply to every file here: the repository is written in English, and a
document that describes the current state is corrected rather than appended to.
`python3 scripts/check-docs.py` fails the suite if a reference points at
something that no longer exists.
