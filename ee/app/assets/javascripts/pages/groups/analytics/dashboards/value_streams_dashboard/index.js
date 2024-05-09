import { createAlert } from '~/alert';
import { __ } from '~/locale';

try {
  (async () => {
    const { default: initApp } = await import('ee/analytics/analytics_dashboards');
    return initApp();
  })();
} catch (error) {
  createAlert({
    message: __('An error occurred. Please try again.'),
    captureError: true,
    error,
  });
}
