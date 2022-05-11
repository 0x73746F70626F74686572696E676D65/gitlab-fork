---
stage: Create
group: Source Code
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
type: reference, concepts
---

# Merge methods **(FREE)**

The merge method you select for your project determines how the changes in your
merge requests are merged into an existing branch.

## Configure a project's merge method

1. On the top bar, select **Menu > Projects** and find your project.
1. On the left sidebar, select **Settings > General**.
1. Expand **Merge requests**.
1. In the **Merge method** section, select your desired merge method.
1. Select **Save changes**.

## Merge commit

This setting is the default. It always creates a separate merge commit,
even when using [squash](../squash_and_merge.md). An example commit graph generated using this merge method:

![Commit graph for merge commits](../img/merge_method_merge_commit_v15_0.png)

- For regular merges, it is equivalent to the command `git merge --no-ff <source-branch>`.
- For squash merges, it squashes all commits in the source branch before merging it normally. It performs actions similar to:

  ```shell
  git checkout `git merge-base <source-branch> <target-branch>`
  git merge --squash <source-branch>
  SOURCE_SHA=`git rev-parse HEAD`
  git checkout <target-branch>
  git merge --no-ff $SOURCE_SHA
  ```

## Merge commit with semi-linear history

A merge commit is created for every merge, but the branch is only merged if
a fast-forward merge is possible. This ensures that if the merge request build
succeeded, the target branch build also succeeds after the merge. An example commit graph generated using this merge method:

![Commit graph for merge commit with semi-linear history](../img/merge_method_merge_commit_with_semi_linear_history_v15_0.png)

When you visit the merge request page with `Merge commit with semi-linear history`
method selected, you can accept it **only if a fast-forward merge is possible**.
When a fast-forward merge is not possible, the user is given the option to rebase, see
[Rebasing in (semi-)linear merge methods](#rebasing-in-semi-linear-merge-methods).

This method is equivalent to the same Git commands as in the **Merge commit** method. However,
if your source branch is based on an out-of-date version of the target branch (such as `main`),
you must rebase your source branch.
This merge method creates a cleaner-looking history, while still enabling you to
see where every branch began and was merged.

## Fast-forward merge

Sometimes, a workflow policy might mandate a clean commit history without
merge commits. In such cases, the fast-forward merge is appropriate. With
fast-forward merge requests, you can retain a linear Git history and a way
to accept merge requests without creating merge commits. An example commit graph
generated using this merge method:

![Commit graph for fast-forward merge](../img/merge_method_ff_v15_0.png)

This method is equivalent to `git merge --ff <source-branch>` for regular merges, and to
`git merge -squash <source-branch>` for squash merges.

When the fast-forward merge
([`--ff-only`](https://git-scm.com/docs/git-merge#git-merge---ff-only)) setting
is enabled, no merge commits are created and all merges are fast-forwarded,
which means that merging is only allowed if the branch can be fast-forwarded.
When a fast-forward merge is not possible, the user is given the option to rebase, see
[Rebasing in (semi-)linear merge methods](#rebasing-in-semi-linear-merge-methods).

NOTE:
Projects using the fast-forward merge strategy can't filter merge requests
[by deployment date](../../../search/index.md#filtering-merge-requests-by-environment-or-deployment-date),
because no merge commit is created.

When you visit the merge request page with `Fast-forward merge`
method selected, you can accept it **only if a fast-forward merge is possible**.

![Fast-forward merge request](../img/ff_merge_mr.png)

## Rebasing in (semi-)linear merge methods

> Rebasing without running a CI/CD pipeline [introduced](https://gitlab.com/gitlab-org/gitlab/-/issues/118825) in GitLab 14.7.

In these merge methods, you can merge only when your source branch is up-to-date with the target branch:

- Merge commit with semi-linear history.
- Fast-forward merge.

If a fast-forward merge is not possible but a conflict-free rebase is possible,
GitLab offers you the [`/rebase` quick action](../../../../topics/git/git_rebase.md#rebase-from-the-gitlab-ui),
and the ability to **Rebase** from the user interface:

![Fast forward merge request](../img/ff_merge_rebase_v14_9.png)

In [GitLab 14.7](https://gitlab.com/gitlab-org/gitlab/-/issues/118825) and later, you can also rebase without running a CI/CD pipeline.

If the target branch is ahead of the source branch and a conflict-free rebase is
not possible, you must rebase the source branch locally before you can do a fast-forward merge.

![Fast forward merge rebase locally](../img/ff_merge_rebase_locally.png)

Rebasing may be required before squashing, even though squashing can itself be
considered equivalent to rebasing.

## Related topics

- [Commits history](../commits.md)
- [Squash and merge](../squash_and_merge.md)
