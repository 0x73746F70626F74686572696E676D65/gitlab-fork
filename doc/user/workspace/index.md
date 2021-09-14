---
stage: Manage
group: Workspace
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Workspace

Workspace will be above the [top-level namespaces](../group/index.md#namespaces) for you to manage everything you can do as a GitLab administrator, including:

- Defining and applying settings to all of your groups, subgroups, and projects.
- Aggregating data from all your groups, subgroups, and projects.

The functionality in the [Admin Area](../admin_area/index.md) of self-managed installations will be split up and go to:

1. Groups (available in the Workspace, Top-level group namespaces, and Sub-groups)
1. Hardware Controls (for functionality that does not apply to groups)

Our goal is to reach feature parity between SaaS and Self-Managed installations, with all [Admin Area settings](/ee/user/admin_area/settings/) moving to either:

- Workspace (contains features relevant to both GitLab-managed and self-managed installations) with a dedicated Settings menu available within the left navigation bar.
- Hardware controls (only contains features relative to Self-Managed installations, with one per installation).

NOTE:
Workspace is currently in development.

## Concept previews

The following provide a preview to the Workspace concept.

![Workspace Overview](img/1.1-Instance_overview.png)

![Groups Overview](img/1.2-Groups_overview.png)

![Admin Overview](img/1.3-Admin.png)

![Admin Overview](img/Admin_Settings.png)

![Admin Overview](img/hardware_settings.png)
