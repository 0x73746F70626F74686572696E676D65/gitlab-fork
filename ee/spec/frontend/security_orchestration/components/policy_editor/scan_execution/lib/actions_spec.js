import { CUSTOM_STRATEGY_OPTIONS_KEYS } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import {
  buildCustomCodeAction,
  buildScannerAction,
  validateStrategyValues,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/actions';
import { REPORT_TYPE_DAST } from '~/vue_shared/security_reports/constants';

const actionId = 'action_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(actionId));

describe('buildCustomCodeAction', () => {
  it('returns a custom code action', () => {
    expect(buildCustomCodeAction()).toEqual({ scan: 'custom', id: actionId });
  });
});

describe('buildScannerAction', () => {
  describe('DAST', () => {
    it('returns a DAST scanner action with empty profiles', () => {
      expect(buildScannerAction({ scanner: REPORT_TYPE_DAST })).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: '',
        scanner_profile: '',
        id: actionId,
      });
    });

    it('returns a DAST scanner action with filled profiles', () => {
      const siteProfile = 'test_site_profile';
      const scannerProfile = 'test_scanner_profile';

      expect(
        buildScannerAction({ scanner: REPORT_TYPE_DAST, siteProfile, scannerProfile }),
      ).toEqual({
        scan: REPORT_TYPE_DAST,
        site_profile: siteProfile,
        scanner_profile: scannerProfile,
        id: actionId,
      });
    });
  });

  describe('non-DAST', () => {
    it('returns a non-DAST scanner action', () => {
      const scanner = 'sast';
      expect(buildScannerAction({ scanner })).toEqual({
        scan: scanner,
        id: actionId,
      });
    });
  });
});

describe('validateStrategyValues', () => {
  it.each`
    input                              | expected
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[0]} | ${true}
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[1]} | ${true}
    ${'other string'}                  | ${false}
  `('validates correctly for $input', ({ input, expected }) => {
    expect(validateStrategyValues(input)).toBe(expected);
  });
});
