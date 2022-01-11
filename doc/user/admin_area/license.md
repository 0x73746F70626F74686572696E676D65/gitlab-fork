---
stage: Growth
group: Conversion
info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#assignments
---

# Activate GitLab Enterprise Edition (EE) **(PREMIUM SELF)**

When you install a new GitLab instance without a license, it only has the Free features
enabled. To enable all features of GitLab Enterprise Edition (EE), activate
your instance with an activation code or a license file. When [the license expires](#what-happens-when-your-license-expires),
some functionality is locked.

## Verify your GitLab edition

To activate your instance, make sure you are running GitLab Enterprise Edition (EE).

To verify the edition, sign in to GitLab and select
**Help** (**{question-o}**) > **Help**. The GitLab edition and version are listed
at the top of the page.

If you are running GitLab Community Edition (CE), upgrade your installation to GitLab
EE. For more details, see [Upgrading between editions](../../update/index.md#upgrading-between-editions).
If you have questions or need assistance upgrading from GitLab CE to EE,
[contact GitLab Support](https://about.gitlab.com/support/#contact-support).

## Activate GitLab EE with an activation code

In GitLab Enterprise Edition 14.1 and later, you need an activation code to activate
your instance. To get an activation code, [purchase a license](https://about.gitlab.com/pricing/)
or sign up for a [free trial](https://about.gitlab.com/free-trial/). The activation
code is a 24-character alphanumeric string you receive in a confirmation email.
You can also sign in to the [Customers Portal](https://customers.gitlab.com/customers/sign_in)
to copy the activation code to your clipboard.

To activate your instance with an activation code:

1. Sign in to your GitLab self-managed instance.
1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Subscription**.
1. Enter the activation code in **Activation code**.
1. Read and accept the terms of service.
1. Select **Activate**.

## Activate GitLab EE with a License File

If you receive a license file from GitLab (for example a new trial), you can upload it by signing into your GitLab instance as an administrator or adding it during installation. The license is a base64-encoded ASCII text file with a `.gitlab-license` extension.

## Uploading your license

The first time you visit your GitLab EE installation signed in as an administrator,
you should see a note urging you to upload a license with a link that takes you
to the **Upload license** page.

Otherwise, to manually go to the **Upload license** page:

1. Sign in to your GitLab self-managed instance.
1. From the top menu, select the Admin Area **{admin}**.
1. On the left sidebar, select **Settings**.
1. In the **License file** section, select **Upload a license**.

   - *If you've received a `.gitlab-license` file:*
     1. Download the license file to your local machine.
     1. Select **Upload `.gitlab-license` file**.
     1. Select **Choose file** and select the license file.
        In this example the license file is named `GitLab.gitlab-license`.
     1. Select the **Terms of Service** checkbox.
     1. Select **Upload License**.

     ![Upload license](img/license_upload_v13_12.png)

   - *If you've received your license as plain text:*
     1. Select **Enter license key**.
     1. Copy the license and paste it into the **License key** field.
     1. Select the **Terms of Service** checkbox.
     1. Select **Upload License**.

## Add your license at install time

A license can be automatically imported at install time by placing a file named
`Gitlab.gitlab-license` in `/etc/gitlab/` for Omnibus GitLab, or `config/` for source installations.

You can also specify a custom location and filename for the license:

- Source installations should set the `GITLAB_LICENSE_FILE` environment
  variable with the path to a valid GitLab Enterprise Edition license.

  ```shell
  export GITLAB_LICENSE_FILE="/path/to/license/file"
  ```

- Omnibus GitLab installations should add this entry to `gitlab.rb`:

  ```ruby
  gitlab_rails['initial_license_file'] = "/path/to/license/file"
  ```

WARNING:
These methods only add a license at the time of installation. Use the
**{admin}** **Admin Area** in the web user interface to renew or upgrade licenses.

---

After the license is uploaded, all GitLab Enterprise Edition functionality
is active until the end of the license period. When that period ends, the
instance will [fall back](#what-happens-when-your-license-expires) to Free-only
functionality.

## What happens when your license expires

One month before the license expires, a message with the upcoming expiration
date displays to GitLab administrators.

When your license expires, GitLab locks features, like Git pushes
and issue creation. Your instance becomes read-only and
an expiration message displays to all administrators. You have a 14-day grace period
before this occurs.

To resume functionality, [upload a new license](#uploading-your-license).

To go back to Free features, [delete all expired licenses](#remove-a-license-file).

## Remove a license file

To remove a license file from a self-managed instance:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Subscription**.
1. Select **Remove license**.

Repeat these steps to remove all licenses, including those applied in the past.

## View license details and history

To view your license details:

1. On the top bar, select **Menu > Admin**.
1. On the left sidebar, select **Subscription**.

You can upload and view more than one license, but only the latest license in
the current date range is the active license.

When you upload a future-dated license, it doesn't take effect until its applicable date.
You can view all active subscriptions in the **Subscription history** table.

NOTE:
In GitLab 13.6 and earlier, a banner about an expiring license may continue to display
when you upload a new license. This happens when the start date of the new license
is in the future and the expiring one is still active.
The banner disappears after the new license becomes active.

## Troubleshooting

### There is no Subscription tab in the Admin Area

If you originally installed Community Edition rather than Enterprise Edition you must
[upgrade to Enterprise Edition](../../update/index.md#community-to-enterprise-edition)
before uploading your license.

GitLab.com users can't upload and use a self-managed license. If you
want to use paid features on GitLab.com, you can
[purchase a separate subscription](../../subscriptions/gitlab_com/index.md).

### Users exceed license limit upon renewal

If you've added new users to your GitLab instance prior to renewal, you may need to
purchase additional seats to cover those users. If this is the case, and a license
without enough users is uploaded, GitLab displays a message prompting you to purchase
additional users. More information on how to determine the required number of users
and how to add additional seats can be found in the
[licensing FAQ](https://about.gitlab.com/pricing/licensing-faq/).

In GitLab 14.2 and later, for instances that use a license file, you can exceed the number of purchased users and still activate your license.

- If the users over license are less than or equal to 10% of the users in the subscription,
  the license is applied and the overage is paid in the next true-up.
- If the users over license are more than 10% of the users in the subscription,
  you cannot apply the license without purchasing more users.

For example, if you purchased a license for 100 users, you can have 110 users when you activate
your license. However, if you have 111, you must purchase more users before you can activate.

### There is a connectivity issue

In GitLab 14.1 and later, to activate your subscription, your GitLab instance must be connected to the internet.

If you have an offline or airgapped environment, you can [upload a license file](license.md#activate-gitlab-ee-with-a-license-file) instead.

If you have questions or need assistance activating your instance, please [contact GitLab Support](https://about.gitlab.com/support/#contact-support).
