# Error Tracking Settings API

> [Introduced](https://gitlab.com/gitlab-org/gitlab/issues/34940) in GitLab 12.7.

## Error Tracking Project Settings

The Project Settings API allows you to retrieve Error Tracking Settings for a Project. Only for project maintainers.

### Retrieve Error Tracking Settings

```
GET /projects/:id/error_tracking/settings
```

| Attribute | Type    | Required | Description           |
| --------- | ------- | -------- | --------------------- |
| `id`      | integer | yes      | The ID of the project owned by the authenticated user |

```bash
curl --header "PRIVATE-TOKEN: <your_access_token>" https://gitlab.example.com/api/v4/projects/1/error_tracking/settings
```

Example response:

```json
{
  "project_name": "sample sentry project",
  "sentry_external_url": "https://sentry.io/myawesomeproject/project",
  "api_url": "https://sentry.io/api/0/projects/myawesomeproject/project"
}
```
