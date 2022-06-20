// CiRunnerUpgradeStatusType

export const UPGRADE_STATUS_AVAILABLE = 'AVAILABLE';
export const UPGRADE_STATUS_RECOMMENDED = 'RECOMMENDED';
export const UPGRADE_STATUS_NOT_AVAILABLE = 'NOT_AVAILABLE';

// Help pages

// Runner install help page is external from this repo, must be
// hardcoded because is located at https://gitlab.com/gitlab-org/gitlab-runner
const RUNNER_HELP_PATH = 'https://docs.gitlab.com/runner';

export const RUNNER_INSTALL_HELP_PATH = `${RUNNER_HELP_PATH}/install/`;

export const RUNNER_VERSION_HELP_PATH = `${RUNNER_HELP_PATH}#gitlab-runner-versions`;
