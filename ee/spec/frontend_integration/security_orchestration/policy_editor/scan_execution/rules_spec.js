import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as urlUtils from '~/lib/utils/url_utility';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import { DEFAULT_ASSIGNED_POLICY_PROJECT } from 'ee/security_orchestration/constants';
import BaseRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/base_rule_component.vue';
import ScheduleRuleComponent from 'ee/security_orchestration/components/policy_editor/scan_execution/rule/schedule_rule_component.vue';
import { SCAN_EXECUTION_SCHEDULE_RULE } from 'ee/security_orchestration/components/policy_editor/scan_execution/constants';
import { DEFAULT_PROVIDE } from '../mocks/mocks';
import { verify } from '../utils';
import { mockPipelineScanExecutionManifest, mockScheduleScanExecutionManifest } from './mocks';

describe('Scan execution policy actions', () => {
  let wrapper;

  const createWrapper = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = mountExtended(App, {
      propsData: {
        assignedPolicyProject: DEFAULT_ASSIGNED_POLICY_PROJECT,
        ...propsData,
      },
      provide: {
        ...DEFAULT_PROVIDE,
        ...provide,
      },
      stubs: {
        SourceEditor: true,
      },
    });
  };

  const findScheduleRuleTypeDropDown = () => wrapper.findByTestId('rule-component-type');

  beforeEach(() => {
    jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('scan_execution_policy');
  });

  afterEach(() => {
    window.gon = {};
  });

  const findBaseRuleComponent = () => wrapper.findComponent(BaseRuleComponent);
  const findScheduleRuleComponent = () => wrapper.findComponent(ScheduleRuleComponent);

  describe('pipeline', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('parses pipeline rule', async () => {
      const verifyRuleMode = () => {
        expect(findBaseRuleComponent().exists()).toBe(true);
        expect(findScheduleRuleComponent().exists()).toBe(false);
      };

      await verify({
        manifest: mockPipelineScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });

  describe('schedule rule', () => {
    beforeEach(() => {
      createWrapper();
    });

    it('parses schedule rule', async () => {
      const verifyRuleMode = () => {
        expect(findScheduleRuleComponent().exists()).toBe(true);
      };

      await findScheduleRuleTypeDropDown().vm.$emit('select', SCAN_EXECUTION_SCHEDULE_RULE);

      await verify({
        manifest: mockScheduleScanExecutionManifest,
        verifyRuleMode,
        wrapper,
      });
    });
  });
});
