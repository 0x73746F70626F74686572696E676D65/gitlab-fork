import initSecurityDashboard from 'ee/security_dashboard/security_dashboard_init';
import { DASHBOARD_TYPES } from 'ee/security_dashboard/store/constants';

initSecurityDashboard(
  document.getElementById('js-project-security-dashboard'),
  DASHBOARD_TYPES.PROJECT,
);
