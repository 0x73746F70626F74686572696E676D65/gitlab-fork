import { GlSprintf, GlLink } from '@gitlab/ui';
import { getSecurityPolicyListUrl } from '~/editor/extensions/source_editor_security_policy_schema_ext';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import DrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import {
  DEFAULT_DESCRIPTION_LABEL,
  ENABLED_LABEL,
  GROUP_TYPE_LABEL,
  INHERITED_LABEL,
  NOT_ENABLED_LABEL,
  PROJECT_TYPE_LABEL,
} from 'ee/security_orchestration/components/policy_drawer/constants';
import ScopeInfoRow from 'ee/security_orchestration/components/policy_drawer/scope_info_row.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockGroupScanExecutionPolicy,
  mockProjectScanExecutionPolicy,
} from '../../mocks/mock_scan_execution_policy_data';

describe('DrawerLayout component', () => {
  let wrapper;

  const DESCRIPTION = 'This policy enforces pipeline configuration to have a job with DAST scan';
  const TYPE = 'Scan Execution';

  const findCustomDescription = () => wrapper.findByTestId('custom-description-text');
  const findDefaultDescription = () => wrapper.findByTestId('default-description-text');
  const findEnabledText = () => wrapper.findByTestId('enabled-status-text');
  const findNotEnabledText = () => wrapper.findByTestId('not-enabled-status-text');
  const findSourceSection = () => wrapper.findByTestId('policy-source');
  const findScopeInfoRow = () => wrapper.findComponent(ScopeInfoRow);
  const findSprintf = () => wrapper.findComponent(GlSprintf);
  const findLink = () => wrapper.findComponent(GlLink);
  const componentStatusText = (status) => (status ? 'does' : 'does not');

  const factory = ({ propsData = {}, provide = {} }) => {
    wrapper = shallowMountExtended(DrawerLayout, {
      provide: {
        namespaceType: NAMESPACE_TYPES.PROJECT,
        ...provide,
      },
      propsData: {
        type: TYPE,
        ...propsData,
      },
      scopedSlots: {
        summary: `<span data-testid="summary-text">Summary</span>`,
        additionalDetails: `<span data-testid="additional-details">More</span>`,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  describe.each`
    context                 | propsData                                                               | enabled  | hasDescription
    ${'enabled policy'}     | ${{ policy: mockProjectScanExecutionPolicy, description: DESCRIPTION }} | ${true}  | ${true}
    ${'not enabled policy'} | ${{ policy: { ...mockProjectScanExecutionPolicy, enabled: false } }}    | ${false} | ${false}
  `('$context', ({ enabled, hasDescription, propsData }) => {
    beforeEach(() => {
      factory({ propsData });
    });

    it.each`
      component                | status                                  | finder                    | exists             | text
      ${'custom description'}  | ${componentStatusText(hasDescription)}  | ${findCustomDescription}  | ${hasDescription}  | ${DESCRIPTION}
      ${'default description'} | ${componentStatusText(!hasDescription)} | ${findDefaultDescription} | ${!hasDescription} | ${DEFAULT_DESCRIPTION_LABEL}
      ${'enabled text'}        | ${componentStatusText(enabled)}         | ${findEnabledText}        | ${enabled}         | ${ENABLED_LABEL}
      ${'not enabled text'}    | ${componentStatusText(!enabled)}        | ${findNotEnabledText}     | ${!enabled}        | ${NOT_ENABLED_LABEL}
    `('$status render the $component', ({ exists, finder, text }) => {
      const component = finder();
      expect(component.exists()).toBe(exists);
      if (exists) {
        expect(component.text()).toBe(text);
      }
    });

    it('matches the snapshots', () => {
      expect(wrapper.element).toMatchSnapshot();
    });
  });

  describe('source field', () => {
    it('displays correctly for a project-level policy being displayed on a project', () => {
      factory({ propsData: { policy: mockProjectScanExecutionPolicy } });
      expect(findSourceSection().text()).toBe(PROJECT_TYPE_LABEL);
    });

    it('displays correctly for a group-level policy being displayed on a project', () => {
      factory({ propsData: { policy: mockGroupScanExecutionPolicy } });
      expect(findSprintf().text()).toMatchInterpolatedText(INHERITED_LABEL);
      expect(findLink().attributes('href')).toBe(
        getSecurityPolicyListUrl({
          namespacePath: mockGroupScanExecutionPolicy.source.namespace.fullPath,
        }),
      );
    });

    it('displays correctly for a group-level policy being displayed on a group', () => {
      factory({
        propsData: { policy: mockProjectScanExecutionPolicy },
        provide: { namespaceType: NAMESPACE_TYPES.GROUP },
      });
      expect(findSourceSection().text()).toBe(GROUP_TYPE_LABEL);
    });
  });

  describe('policy without source namespace', () => {
    it.each`
      namespaceType              | inherited | expectedResult
      ${NAMESPACE_TYPES.GROUP}   | ${true}   | ${'This policy is inherited'}
      ${NAMESPACE_TYPES.PROJECT} | ${true}   | ${'This policy is inherited'}
      ${NAMESPACE_TYPES.GROUP}   | ${false}  | ${'This is a group-level policy'}
      ${NAMESPACE_TYPES.PROJECT} | ${false}  | ${'This is a project-level policy'}
    `(
      'should not render link for policies without namespace',
      ({ namespaceType, inherited, expectedResult }) => {
        factory({
          propsData: {
            policy: {
              ...mockProjectScanExecutionPolicy,
              source: {
                __typename: 'GroupSecurityPolicySource',
                inherited,
                namespace: undefined,
              },
            },
          },
          provide: { namespaceType },
        });

        expect(findLink().exists()).toBe(false);
        expect(findSourceSection().text()).toBe(expectedResult);
      },
    );
  });

  describe('policy scope', () => {
    it.each`
      namespaceType
      ${NAMESPACE_TYPES.PROJECT}
      ${NAMESPACE_TYPES.GROUP}
    `(`renders policy scope for $namespaceType`, ({ namespaceType }) => {
      factory({
        propsData: {
          policy: mockProjectScanExecutionPolicy,
        },
        provide: {
          namespaceType,
        },
      });

      expect(findScopeInfoRow().exists()).toBe(true);
    });
  });
});
