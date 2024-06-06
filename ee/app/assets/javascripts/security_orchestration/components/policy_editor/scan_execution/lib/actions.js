import { uniqueId } from 'lodash';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';
import { CUSTOM_ACTION_KEY, CUSTOM_STRATEGY_OPTIONS_KEYS } from '../constants';

export const buildScannerAction = ({ scanner, siteProfile = '', scannerProfile = '', id }) => {
  const action = { scan: scanner, id: id ?? uniqueId('action_') };

  if (scanner === REPORT_TYPE_DAST) {
    action.site_profile = siteProfile;
    action.scanner_profile = scannerProfile;
  }

  return action;
};

export const buildCustomCodeAction = (id) => {
  return { scan: CUSTOM_ACTION_KEY, id: id || uniqueId('action_') };
};

export const validateStrategyValues = (value) => CUSTOM_STRATEGY_OPTIONS_KEYS.includes(value);
