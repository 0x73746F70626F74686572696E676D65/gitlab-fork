---
stage: Monitor
group: Respond
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/product/ux/technical-writing/#assignments
---

# Grafana Configuration **(FREE SELF)**

> [Deprecated](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/7772) in GitLab 16.0.

WARNING:
Bundled Grafana was deprecated GitLab 16.0 and is no longer supported. It will be removed in GitLab 16.3.
For more information, see [deprecation notes](#deprecation-of-bundled-grafana).

[Grafana](https://grafana.com/) is a tool that enables you to visualize time
series metrics through graphs and dashboards. GitLab writes performance data to Prometheus,
and Grafana allows you to query the data to display graphs.

## Deprecation of bundled Grafana

Bundled Grafana was an optional Omnibus GitLab service that provided a user interface to GitLab metrics.

The version of Grafana that is bundled with Omnibus GitLab is no longer supported. If you're using the bundled Grafana, you
should switch to a newer version from [Grafana Labs](https://grafana.com/grafana/).

### Switch to new Grafana instance

To switch away from bundled Grafana to a newer version of Grafana from Grafana Labs:

1. Set up a version of Grafana from Grafana Labs.
1. [Export the existing dashboards](https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#export-a-dashboard) from bundled Grafana.
1. [Import the existing dashboards](https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#import-a-dashboard) in the new Grafana instance.
1. [Configure GitLab](#integrate-with-gitlab-ui) to use the new Grafana instance.

### Temporary workaround

In GitLab versions 16.0 to 16.2, you can still force Omnibus GitLab to enable and configure Grafana by setting the following:

- `grafana['enable'] = true`.
- `grafana['enable_deprecated_service'] = true`.

You see a deprecation message when reconfiguring GitLab.

## Configure Grafana

Prerequisites:

- Grafana installed.

1. Log in to Grafana as the administration user.
1. Select **Data Sources** from the **Configuration** menu.
1. Select **Add data source**.
1. Select the required data source type. For example, [Prometheus](../prometheus/index.md#prometheus-as-a-grafana-data-source).
1. Complete the details for the data source and select **Save & Test**.

Grafana should indicate the data source is working.

## Import dashboards

You can now import a set of default dashboards to start displaying information.
GitLab has published a set of default
[Grafana dashboards](https://gitlab.com/gitlab-org/grafana-dashboards) to get you started. To use
them:

1. Clone the repository, or download a ZIP file or tarball.
1. Follow these steps to import each JSON file individually:

   1. Log in to Grafana as the administration user.
   1. Select **Manage** from the **Dashboards** menu.
   1. Select **Import**, then **Upload JSON file**.
   1. Locate the JSON file to import and select **Choose for Upload**. Select **Import**.
   1. After the dashboard is imported, select the **Save dashboard** icon in the top bar.

If you don't save the dashboard after importing it, the dashboard is removed
when you navigate away from the page. Repeat this process for each dashboard you wish to import.

Alternatively, you can import all the dashboards into your Grafana
instance. For more information about this process, see the
[README of the Grafana dashboards](https://gitlab.com/gitlab-org/grafana-dashboards)
repository.

## Integrate with GitLab UI

> [Introduced](https://gitlab.com/gitlab-org/gitlab-foss/-/issues/61005) in GitLab 12.1.

After setting up Grafana, you can enable a link to access it from the
GitLab sidebar:

1. On the left sidebar, expand the top-most chevron (**{chevron-down}**).
1. Select **Admin Area**.
1. On the left sidebar, select **Settings > Metrics and profiling**
   and expand **Metrics - Grafana**.
1. Select the **Add a link to Grafana** checkbox.
1. Configure the **Grafana URL**:
   - *If Grafana is enabled through Omnibus GitLab and on the same server,*
     leave **Grafana URL** unchanged. It should be `/-/grafana`.
   - *Otherwise,* enter the full URL of the Grafana instance.
1. Select **Save changes**.

GitLab displays your link in the **Main menu > Admin > Monitoring > Metrics Dashboard**.

## Required Scopes

> [Introduced](https://gitlab.com/gitlab-org/omnibus-gitlab/-/issues/5822) in GitLab 13.10.

When setting up Grafana through the process above, no scope shows in the screen at
**Main menu > Admin > Applications > GitLab Grafana**. However, the `read_user` scope is
required and is provided to the application automatically. Setting any scope other than
`read_user` without also including `read_user` leads to this error when you try to sign in using
GitLab as the OAuth provider:

```plaintext
The requested scope is invalid, unknown, or malformed.
```

If you see this error, make sure that one of the following is true in the GitLab Grafana
configuration screen:

- No scopes appear.
- The `read_user` scope is included.

> Versions of GitLab prior 13.10 use the API scope instead of `read_user`. In versions of GitLab
> prior to 13.10, the API scope:
>
> - Is required to access Grafana through the GitLab OAuth provider.
> - Is set by enabling the Grafana application as shown in [Integration with GitLab UI](#integrate-with-gitlab-ui).

## Security Update

Users running GitLab version 12.0 or later should immediately upgrade to one of the
following security releases due to a known vulnerability with the embedded Grafana dashboard:

- 12.0.6
- 12.1.6

After upgrading, the Grafana dashboard is disabled, and the location of your
existing Grafana data is changed from `/var/opt/gitlab/grafana/data/` to
`/var/opt/gitlab/grafana/data.bak.#{Date.today}/`.

To prevent the data from being relocated, you can run the following command prior to upgrading:

```shell
echo "0" > /var/opt/gitlab/grafana/CVE_reset_status
```

To reinstate your old data, move it back into its original location:

```shell
sudo mv /var/opt/gitlab/grafana/data.bak.xxxx/ /var/opt/gitlab/grafana/data/
```

However, you should **not** reinstate your old data _except_ under one of the following conditions:

1. If you're certain that you changed your default administration password when you enabled Grafana.
1. If you run GitLab in a private network, accessed only by trusted users, and your
   Grafana login page has not been exposed to the internet.

If you require access to your old Grafana data but don't meet one of these criteria, you may consider:

1. Reinstating it temporarily.
1. [Exporting the dashboards](https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#export-and-import-dashboards) you need.
1. Refreshing the data and [re-importing your dashboards](https://grafana.com/docs/grafana/latest/dashboards/manage-dashboards/#export-and-import-dashboards).

WARNING:
These actions pose a temporary vulnerability while your old Grafana data is in use.
Deciding to take any of these actions should be weighed carefully with your need to access
existing data and dashboards.

For more information and further mitigation details, refer to our
[blog post on the security release](https://about.gitlab.com/releases/2019/08/12/critical-security-release-gitlab-12-dot-1-dot-6-released/).

Read more on:

- [Introduction to GitLab Performance Monitoring](index.md)
- [GitLab Configuration](gitlab_configuration.md)
