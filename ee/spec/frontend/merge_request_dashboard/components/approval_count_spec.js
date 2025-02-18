import { shallowMount } from '@vue/test-utils';
import { GlBadge } from '@gitlab/ui';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import ApprovalCount from 'ee/merge_request_dashboard/components/approval_count.vue';
import ApprovalCountFOSS from '~/merge_request_dashboard/components/approval_count.vue';

let wrapper;

function createComponent(propsData = {}) {
  wrapper = shallowMount(ApprovalCount, {
    propsData,
    directives: {
      GlTooltip: createMockDirective('gl-tooltip'),
    },
  });
}

const findFossApprovalCount = () => wrapper.findComponent(ApprovalCountFOSS);
const findBadge = () => wrapper.findComponent(GlBadge);
const findTooltip = () => getBinding(findBadge().element, 'gl-tooltip');

describe('Merge request dashboard approval count FOSS component', () => {
  describe('when approvals are not required', () => {
    it('renders approval count FOSS component', () => {
      createComponent({
        mergeRequest: { approvalsRequired: 0 },
      });

      expect(findFossApprovalCount().exists()).toBe(true);
      expect(findFossApprovalCount().props('mergeRequest')).toEqual(
        expect.objectContaining({
          approvalsRequired: 0,
        }),
      );
    });
  });

  describe('when approvals are required', () => {
    it('renders badge when merge request is approved', () => {
      createComponent({
        mergeRequest: { approvalsRequired: 1, approvalsLeft: 1 },
      });

      expect(findBadge().exists()).toBe(true);
    });

    it.each`
      approved | approvalsRequired | approvalsLeft | tooltipTitle
      ${false} | ${1}              | ${1}          | ${'Required approvals (0 of 1 given)'}
      ${false} | ${1}              | ${0}          | ${'Required approvals (1 of 1 given)'}
    `(
      'renders badge with correct tooltip title',
      ({ approved, approvalsRequired, approvalsLeft, tooltipTitle }) => {
        createComponent({
          mergeRequest: { approved, approvalsRequired, approvalsLeft },
        });

        expect(findTooltip().value).toBe(tooltipTitle);
      },
    );

    it.each`
      approved | approvalsRequired | approvalsLeft | tooltipTitle
      ${false} | ${1}              | ${1}          | ${'0 of 1 Approvals'}
      ${false} | ${1}              | ${0}          | ${'1 of 1 Approvals'}
      ${true}  | ${1}              | ${0}          | ${'Approved'}
    `(
      'renders badge with correct tooltip title',
      ({ approved, approvalsRequired, approvalsLeft, tooltipTitle }) => {
        createComponent({
          mergeRequest: { approved, approvalsRequired, approvalsLeft },
        });

        expect(findBadge().text()).toBe(tooltipTitle);
      },
    );
  });
});
