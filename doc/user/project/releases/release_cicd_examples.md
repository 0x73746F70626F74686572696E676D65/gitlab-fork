---
stage: Release
group: Release
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Release CI/CD examples

GitLab release functionality is flexible, able to be configured to match your workflow. This page
features example CI/CD release jobs. Each example demonstrates a method of creating a release in a
CI/CD pipeline.

## Create a release when a Git tag is created

In this CI/CD example, pushing a Git tag to the repository, or creating a Git tag in the UI triggers
the release. You can use this method if you prefer to create the Git tag manually, and create a
release as a result.

NOTE:
Do not provide Release notes when you create the Git tag in the UI. Providing release notes
creates a release, resulting in the pipeline failing.

Key points in the following _extract_ of an example `.gitlab-ci.yml` file:

- The `rules` stanza defines when the job is added to the pipeline.
- The Git tag is used in the release's name and description.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  rules:
    - if: $CI_COMMIT_TAG                 # Run this job when a tag is created
  script:
    - echo "running release_job"
  release:                               # See https://docs.gitlab.com/ee/ci/yaml/#release for available properties
    tag_name: '$CI_COMMIT_TAG'
    description: '$CI_COMMIT_TAG'
```

## Create a release when a commit is merged to the default branch

In this CI/CD example, merging a commit to the default branch triggers the pipeline. You can use
this method if your release workflow does not create a tag manually.

Key points in the following _extract_ of an example `.gitlab-ci.yml` file:

- The Git tag, description, and reference are created automatically in the pipeline.
- If you manually create a tag, the `release_job` job does not run.

```yaml
release_job:
  stage: release
  image: registry.gitlab.com/gitlab-org/release-cli:latest
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                  # Do not run this job when a tag is created manually
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "running release_job for $TAG"
  release:                                         # See https://docs.gitlab.com/ee/ci/yaml/#release for available properties
    tag_name: 'v0.$CI_PIPELINE_IID'                # The version is incremented per pipeline.
    description: 'v0.$CI_PIPELINE_IID'
    ref: '$CI_COMMIT_SHA'                          # The tag is created from the pipeline SHA.
```

NOTE:
Environment variables set in `before_script` or `script` are not available for expanding
in the same job. Read more about
[potentially making variables available for expanding](https://gitlab.com/gitlab-org/gitlab-runner/-/issues/6400).

## Skip multiple pipelines when creating a release

Creating a release using a CI/CD job could potentially trigger multiple pipelines if the associated tag does not exist already. To understand how this might happen, consider the following workflows:

- Tag first, release second:
  1. A tag is created via UI or pushed.
  1. A tag pipeline is triggered, and runs `release` job.
  1. A release is created.

- Release first, tag second:
  1. A pipeline is triggered when commits are pushed or merged to default branch. The pipeline runs `release` job.
  1. A release is created.
  1. A tag is created.
  1. A tag pipeline is triggered. The pipeline also runs `release` job.

In the second workflow, the `release` job runs in multiple pipelines. To prevent this, you can use the [`workflow:rules` keyword](../../../ci/yaml/index.md#workflowrules) to determine if a release job should run in a tag pipeline:

```yaml
release_job:
  rules:
    - if: $CI_COMMIT_TAG
      when: never                                  # Do not run this job in a tag pipeline
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH  # Run this job when commits are pushed or merged to the default branch
  script:
    - echo "Create release"
  release:
    name: 'My awesome release'
    tag_name: '$CI_COMMIT_TAG'
```
