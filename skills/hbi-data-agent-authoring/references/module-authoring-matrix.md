# Data Agent authoring module matrix

This matrix is the execution guide for a server-issued `data-agent-session-v1`
session. It describes the CLI workflow and the expected server boundary; it is
not a permission list. Everest's delegated route catalog, the logged-in user's
native ACL, and the owning service validator remain authoritative.

## Module lanes

| Module | Start with | Recoverable authoring lane | Keep blocked in this contract |
| --- | --- | --- | --- |
| Application and data | `hbi search`, `hbi app`, `hbi folder`, `hbi connection` | app/folder content, app relations/parameters/portal, file-backed dataset upload/preview/save, dataset definitions and metadata, relation model, metric/measure definitions; successful writes are confirmed by the owning resource audit and update SSE | credentials, connection authorization/replacement writes, publish/share, ownership transfer, permanent purge |
| Dashboard | `hbi dashboard show` or `hbi dashboard plan scaffold` | dashboard shell, duplicate, bounded plan/element patch, image upload/delete, approved theme fields | publish/share/export side effects, arbitrary runtime option patches, global theme creation |
| Indicator center | `hbi subject`, `hbi measure`, `hbi kanban` | subject membership, metric visibility, analysis-board content and duplication; membership uses folder audit/update SSE and board writes use kanban audit/update SSE | notification/export side effects; permission changes go through `app.authorize` / `app.rule.*` proposals |
| Pipeline | `hbi pipeline show`, then `hbi pipeline node` | pipeline definition/duplicate, node content edits (including file-node upload/save), node preview/distinct/SQL and table-property template evidence; writes produce pipeline audit/update SSE | schedule creation/changes, autonomous execution, and `test-create` operations that touch an external sink |
| Notebook | `hbi notebook show`, `hbi notebook languages` | notebook and paragraph content, connection-table discovery | paragraph execution and connection grant/revoke/remove |
| Survey / data entry | `hbi survey list`, `hbi survey show`, `hbi survey setting get` | survey template create/update from a full JSON document, including checkbox multi-select controls; control removal only with an explicit `--allow-remove-controls`; the fill switch (`setting update --status`); filling-data reads | template delete, allowUsers/share changes, platform-level template management, async import/export |
| Automation | `hbi scheduler list`, `hbi data-alert show` | existing schedule/context/log/result/DAG inspection, alert preview and validation; scheduler create/update/switch/delete are proposed with `hbi data-agent operation propose --kind scheduler.*`, and alert create/update/delete with `--kind data-alert.*`, each completed only after user confirmation | alert enablement and notification test still need a receipt; pipeline runs use a ONCE `scheduler.create` |

## Execution contract

For every lane:

1. Read the session envelope and the current `clientContext`; treat both as
   routing context, never as ACL evidence.
2. Locate the canonical target with `search`, `list`, or `show`. Do not infer
   IDs from titles or reuse a stale ID from another module.
3. Read the target immediately before a mutation and use the returned IDs and
   revision fields in the next typed command.
4. Prefer the domain skill's typed command and `--dry-run`/validation helper.
   Do not fall back to a generic raw update or handcrafted HTTP request.
5. A successful mutation must identify the changed resource. The job trace and
   normal resource-update SSE are the verification signals; the browser does
   not need to be navigated for the operation to be valid.
6. Stop on `POLICY_DENIED`, `401`, `403`, not-found, or business validation
   errors. Do not retry through a neighboring command family.
7. A high-risk proposal is only a UI confirmation candidate. The
   `operation.proposed` stream event and CLI output expose the operation id and
   fingerprint; query the terminal operation receipt after the user-facing
   confirmation instead of treating the proposal as execution evidence.

## Multi-module authoring

Use `hbi-workflow` when a request crosses module boundaries. Keep each stage's
IDs and receipts as explicit inputs to the next stage:

```text
locate data-app/connection
  -> create or inspect dataset
  -> inspect relation/model and define metric/measure
  -> create analytic app/dashboard shell
  -> apply dashboard plan/elements
  -> optionally organize measures in a subject/kanban
```

If any stage reaches a blocked boundary, report the completed stages and the
exact blocked operation. Do not silently downgrade the request to a partial
write or claim that a page navigation implies success.

When authoring starts without selected data sources, adding a metric to a
subject is still not an open reference operation: the server checks the real
user's application read ACL and resolves the metric through the dataset
service. A candidate found by search is not enough evidence, and an
unavailable check is a fail-closed denial.

## Confirmation boundary

Recoverable content edits may run in the current session. Confirmation is a
server-owned, operation-bound receipt with an `operationId`, payload
fingerprint, expiry, current-user/ACL revalidation, and terminal status.
Scheduler creation is the first admitted high-risk operation:

```bash
hbi data-agent operation propose --kind scheduler.create \
  --file plan.json --interaction-mode interactive --output json
hbi data-agent operation get <operation_id> --output json
```

The CLI never confirms the proposal. The user-facing Everest endpoint performs
confirmation and execution, after which the agent may query the terminal
receipt. Other scheduler/alert/publish/share/permission/credential/execution
families remain fail-closed until they receive an equivalent operation
(sharing/publishing, credential replacement, ownership, permanent purge)
contract. Non-interactive proposals expire without invoking the route.
