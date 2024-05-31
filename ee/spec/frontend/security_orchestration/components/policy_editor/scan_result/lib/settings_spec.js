import {
  PREVENT_APPROVAL_BY_AUTHOR,
  buildSettingsList,
  mergeRequestConfiguration,
  protectedBranchesConfiguration,
  pushingBranchesConfiguration,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/settings';

const defaultSettings = buildSettingsList();

describe('approval_settings', () => {
  describe('buildSettingsList', () => {
    it('returns the default settings', () => {
      expect(buildSettingsList()).toEqual(defaultSettings);
    });

    it('can update merge request settings', () => {
      const settings = {
        ...pushingBranchesConfiguration,
        ...mergeRequestConfiguration,
        [PREVENT_APPROVAL_BY_AUTHOR]: false,
      };
      expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
        ...protectedBranchesConfiguration,
        ...settings,
      });
    });

    it('has fall back values for settings', () => {
      const settings = {
        [PREVENT_APPROVAL_BY_AUTHOR]: true,
      };

      expect(buildSettingsList({ settings, hasAnyMergeRequestRule: true })).toEqual({
        ...defaultSettings,
        ...settings,
      });
    });
  });
});
