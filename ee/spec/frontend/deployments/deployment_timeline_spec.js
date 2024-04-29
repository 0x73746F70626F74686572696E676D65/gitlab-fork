import { GlAvatarLink, GlAvatar, GlBadge } from '@gitlab/ui';
import mockDeploymentFixture from 'test_fixtures/ee/graphql/deployments/graphql/queries/deployment.query.graphql.json';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import DeploymentTimeline from 'ee/deployments/components/deployment_timeline.vue';

const { approvalSummary } = mockDeploymentFixture.data.project.deployment;

describe('ee/deployments/components/deployment_timeline.vue', () => {
  let wrapper;

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(DeploymentTimeline, {
      propsData: {
        approvalSummary,
        ...propsData,
      },
    });
  };

  const getAllApprovals = () => approvalSummary.rules.flatMap((rule) => rule.approvals);
  const getRelatedRule = (approval) =>
    approvalSummary.rules.find((rule) =>
      rule?.approvals.find((ruleApproval) => ruleApproval.user.name === approval.user.name),
    );
  const getRoleName = (rule) => rule.user?.name || rule.group?.name;

  describe('with approval', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows all approval comments', () => {
      getAllApprovals().forEach((approval) => {
        expect(wrapper.findByText(approval.comment).exists()).toBe(true);
      });
    });

    it('shows the user who made the approval', () => {
      getAllApprovals().forEach(({ user }) => {
        const approvalBlock = wrapper.findByTestId(`approval-${user.username}`);
        const avatarLink = approvalBlock.findComponent(GlAvatarLink);
        expect(avatarLink.attributes('href')).toBe(user.webUrl);

        const avatar = approvalBlock.findComponent(GlAvatar);
        expect(avatar.attributes()).toMatchObject({
          src: user.avatarUrl,
          alt: user.name,
        });
        expect(avatar.props('entityName')).toBe(user.username);
      });
    });

    it('shows when the comment was made', () => {
      getAllApprovals().forEach((approval) => {
        const approvalBlock = wrapper.findByTestId(`approval-${approval.user.username}`);

        const timeago = approvalBlock.findComponent(TimeAgoTooltip);

        expect(timeago.props('time')).toBe(approval.createdAt);
      });
    });

    it('shows a badge showing if a comment is an approval', () => {
      getAllApprovals().forEach((approval) => {
        const approvalBlock = wrapper.findByTestId(`approval-${approval.user.username}`);

        const badge = approvalBlock.findComponent(GlBadge);

        expect(badge.text()).toBe('Approved');
        expect(badge.props('variant')).toBe('success');
      });
    });

    it('shows a tooltip with the role user approved for', () => {
      getAllApprovals().forEach((approval) => {
        const approvalBlock = wrapper.findByTestId(`approval-${approval.user.username}`);
        const badge = approvalBlock.findComponent(GlBadge);

        const relatedRule = getRelatedRule(approval);
        const role = getRoleName(relatedRule);

        expect(badge.attributes('title')).toBe(`Approved as ${role}`);
      });
    });
  });

  describe('with rejection', () => {
    beforeEach(() => {
      const [rule] = approvalSummary.rules;
      const [approval] = rule.approvals;

      createComponent({
        propsData: {
          approvalSummary: {
            ...approvalSummary,
            rules: [
              {
                ...rule,
                approvals: [
                  {
                    ...approval,
                    status: 'REJECTED',
                  },
                ],
              },
            ],
          },
        },
      });
    });

    it('shows a badge showing if a comment is a rejection', () => {
      getAllApprovals().forEach((approval) => {
        const approvalBlock = wrapper.findByTestId(`approval-${approval.user.username}`);

        const badge = approvalBlock.findComponent(GlBadge);

        expect(badge.text()).toBe('Rejected');
        expect(badge.props('variant')).toBe('danger');
      });
    });

    it('shows a tooltip with the role user approved for', () => {
      getAllApprovals().forEach((approval) => {
        const approvalBlock = wrapper.findByTestId(`approval-${approval.user.username}`);
        const badge = approvalBlock.findComponent(GlBadge);

        const relatedRule = getRelatedRule(approval);
        const role = getRoleName(relatedRule);

        expect(badge.attributes('title')).toBe(`Rejected as ${role}`);
      });
    });
  });
});
