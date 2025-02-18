import { GlFormCheckbox, GlIcon, GlSkeletonLoader } from '@gitlab/ui';
import { createWrapper, mount, shallowMount } from '@vue/test-utils';
import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { cloneDeep } from 'lodash';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecurityDashboardTableRow from 'ee/security_dashboard/components/pipeline/security_dashboard_table_row.vue';
import VulnerabilityActionButtons from 'ee/security_dashboard/components/pipeline/vulnerability_action_buttons.vue';
import { setupStore } from 'ee/security_dashboard/store';
import { VULNERABILITY_MODAL_ID } from 'ee/vue_shared/security_reports/components/constants';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import { trimText } from 'helpers/text_helper';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import VulnerabilityIssueLink from 'ee/security_dashboard/components/pipeline/vulnerability_issue_link.vue';
import { getCreatedIssueForVulnerability } from 'ee/vue_shared/security_reports/components/helpers';
import mockDataVulnerabilities, {
  issueData,
} from '../../store/modules/vulnerabilities/data/mock_data_vulnerabilities';

Vue.use(Vuex);

describe('Security Dashboard Table Row', () => {
  let wrapper;
  let store;

  const createComponent = (mountFunc, { props = {}, canAdminVulnerability = true } = {}) => {
    wrapper = mountFunc(SecurityDashboardTableRow, {
      store,
      provide: { canAdminVulnerability, projectFullPath: 'group/project', pipeline: { iid: 1 } },
      propsData: {
        ...props,
      },
    });
  };

  beforeEach(() => {
    store = new Vuex.Store();
    setupStore(store);
    jest.spyOn(store, 'dispatch');
  });

  const findLoader = () => wrapper.findComponent(GlSkeletonLoader);
  const findContent = (i) => wrapper.findAll('.table-mobile-content').at(i);
  const findVulnerabilityIssueLink = () => wrapper.findComponent(VulnerabilityIssueLink);
  const hasSelectedClass = () => wrapper.classes('gl-bg-blue-50');
  const findCheckbox = () => wrapper.findComponent(GlFormCheckbox);
  const findSeverityBadge = () => wrapper.findComponent(SeverityBadge);
  const findDismissalLabel = () => wrapper.findByTestId('dismissal-label');
  const findDismissalCommentIcon = () => wrapper.findComponent(GlIcon);

  describe('when loading', () => {
    beforeEach(() => {
      createComponent(shallowMount, { props: { isLoading: true } });
    });

    it('should display the skeleton loader', () => {
      expect(findLoader().exists()).toBe(true);
    });

    it('should not render the severity', () => {
      expect(findSeverityBadge().exists()).toBe(false);
    });

    it('should render a `` for the report type and scanner', () => {
      expect(findContent(3).text()).toEqual('');
      expect(wrapper.find('vulnerability-vendor').exists()).toBe(false);
    });

    it('should not render action buttons', () => {
      expect(wrapper.findAll('.action-buttons button')).toHaveLength(0);
    });
  });

  describe('when loaded', () => {
    let vulnerability = mockDataVulnerabilities[0];

    beforeEach(() => {
      createComponent(mount, { props: { vulnerability } });
    });

    it('should not display the skeleton loader', () => {
      expect(findLoader().exists()).toBe(false);
    });

    it('should render the severity', () => {
      expect(findSeverityBadge().text().toLowerCase()).toBe(vulnerability.severity);
    });

    it('should render the identifier cell', () => {
      const { identifiers } = vulnerability;
      expect(findContent(2).text()).toContain(identifiers[0].name);
      expect(trimText(findContent(2).text())).toContain(`${identifiers.length - 1} more`);
    });

    it('should render the report type', () => {
      expect(findContent(3).text().toLowerCase()).toContain(
        vulnerability.report_type.toLowerCase(),
      );
    });

    it('should render the scanner vendor if the scanner does exist', () => {
      expect(findContent(3).text()).toContain(vulnerability.scanner.vendor);
    });

    describe('the project name', () => {
      it('should render the name', () => {
        expect(findContent(1).text()).toContain(vulnerability.name);
      });

      it('should render the project namespace', () => {
        expect(findContent(1).text()).toContain(vulnerability.location.file);
      });

      it('should fire the setModalData action and open the modal when clicked', () => {
        const rootWrapper = createWrapper(wrapper.vm.$root);
        jest.spyOn(store, 'dispatch').mockImplementation();

        const el = wrapper.findComponent({ ref: 'vulnerability-title' });
        el.trigger('click');

        expect(store.dispatch).toHaveBeenCalledWith('vulnerabilities/setModalData', {
          vulnerability,
        });

        expect(rootWrapper.emitted(BV_SHOW_MODAL)[0]).toContain(VULNERABILITY_MODAL_ID);
      });
    });

    describe('Non-group Security Dashboard', () => {
      beforeEach(() => {
        // eslint-disable-next-line prefer-destructuring
        vulnerability = mockDataVulnerabilities[7];

        createComponent(shallowMount, { props: { vulnerability } });
      });

      it('should contain container image as the namespace', () => {
        expect(findContent(1).text()).toContain(vulnerability.location.image);
      });
    });
  });

  describe('vulnerability dismissal', () => {
    let vulnerability;

    beforeEach(() => {
      vulnerability = cloneDeep(mockDataVulnerabilities[0]);
    });

    it.each`
      stateTransitions                                   | isLabelShown | isIconShown
      ${[{ to_state: 'dismissed' }]}                     | ${true}      | ${false}
      ${[{ to_state: 'dismissed', comment: 'comment' }]} | ${true}      | ${true}
      ${[{}, {}, { to_state: 'dismissed' }]}             | ${true}      | ${false}
      ${[]}                                              | ${false}     | ${false}
      ${[{ to_state: 'detected' }]}                      | ${false}     | ${false}
    `(
      'shows dismissal badge: $isLabelShown, shows dismissal comment icon: $isIconShown',
      ({ stateTransitions, isLabelShown, isIconShown }) => {
        vulnerability.state_transitions = stateTransitions;
        createComponent(shallowMountExtended, { props: { vulnerability } });

        expect(findDismissalLabel().exists()).toBe(isLabelShown);
        expect(findDismissalCommentIcon().exists()).toBe(isIconShown);
      },
    );
  });

  describe('with created issue', () => {
    const vulnerability = mockDataVulnerabilities[3];

    it('shows the vulnerability issue link with the expected props', () => {
      createComponent(shallowMount, { props: { vulnerability } });

      expect(findVulnerabilityIssueLink().props()).toMatchObject({
        issue: getCreatedIssueForVulnerability(vulnerability),
        projectName: vulnerability.project.name,
      });
    });
  });

  describe('with no created issue', () => {
    const vulnerability = mockDataVulnerabilities[0];

    beforeEach(() => {
      createComponent(shallowMount, { props: { vulnerability } });
    });

    it('should not show the vulnerability issue link', () => {
      expect(findVulnerabilityIssueLink().exists()).toBe(false);
    });

    it('should be unselected', () => {
      expect(hasSelectedClass()).toBe(false);
      expect(findCheckbox().attributes('checked')).toBe(undefined);
    });

    describe('when checked', () => {
      beforeEach(() => {
        findCheckbox().vm.$emit('change');
      });

      it('should be selected', () => {
        expect(hasSelectedClass()).toBe(true);
        expect(findCheckbox().attributes('checked')).toBe('true');
      });

      it('should update store', () => {
        expect(store.dispatch).toHaveBeenCalledWith(
          'vulnerabilities/selectVulnerability',
          vulnerability,
        );
      });

      describe('when unchecked', () => {
        beforeEach(() => {
          findCheckbox().vm.$emit('change');
        });

        it('should be unselected', () => {
          expect(hasSelectedClass()).toBe(false);
          expect(findCheckbox().attributes('checked')).toBe(undefined);
        });

        it('should update store', () => {
          expect(store.dispatch).toHaveBeenCalledWith(
            'vulnerabilities/deselectVulnerability',
            vulnerability,
          );
        });
      });
    });
  });

  describe('with less than two identifiers', () => {
    const vulnerability = mockDataVulnerabilities[1];

    beforeEach(() => {
      createComponent(shallowMount, { props: { vulnerability } });
    });

    it('should render the identifier cell', () => {
      const { identifiers } = vulnerability;
      expect(findContent(2).text()).toBe(identifiers[0].name);
    });
  });

  describe.each`
    createGitLabIssuePath | createJiraIssueUrl  | canCreateIssue
    ${''}                 | ${''}               | ${false}
    ${''}                 | ${'http://foo.bar'} | ${true}
    ${'/foo/bar'}         | ${''}               | ${true}
    ${'/foo/bar'}         | ${'http://foo.bar'} | ${true}
  `(
    'with createGitLabIssuePath set to "$createGitLabIssuePath" and createJiraIssueUrl to "$createJiraIssueUrl"',
    ({ createGitLabIssuePath, createJiraIssueUrl, canCreateIssue }) => {
      beforeEach(() => {
        const vulnerability = mockDataVulnerabilities[1];
        vulnerability.create_vulnerability_feedback_issue_path = createGitLabIssuePath;
        vulnerability.create_jira_issue_url = createJiraIssueUrl;

        createComponent(shallowMount, { props: { vulnerability } });
      });

      it(`should pass "canCreateIssue" as "${canCreateIssue}" to the action-buttons component`, () => {
        expect(wrapper.findComponent(VulnerabilityActionButtons).props('canCreateIssue')).toBe(
          canCreateIssue,
        );
      });
    },
  );

  describe('with Jira issue-integration enabled', () => {
    describe('with an existing GitLab issue', () => {
      beforeEach(() => {
        const vulnerability = {
          ...mockDataVulnerabilities[1],
          issue_links: [issueData],
          create_jira_issue_url: 'http://jira.example.com',
        };

        createComponent(shallowMountExtended, { props: { vulnerability } });
      });

      it('allows the creation of a Jira issue', () => {
        expect(wrapper.findComponent(VulnerabilityActionButtons).props('canCreateIssue')).toBe(
          true,
        );
      });
    });

    describe('with an existing Jira issue', () => {
      const jiraIssueDetails = {
        external_issue_details: {
          external_tracker: 'jira',
          web_url: 'http://jira.example.com/GTA-1',
          references: {
            relative: 'GTA#1',
          },
        },
      };

      beforeEach(() => {
        const vulnerability = {
          ...mockDataVulnerabilities[1],
          external_issue_links: [jiraIssueDetails],
          create_jira_issue_url: 'http://jira.example.com',
        };

        createComponent(shallowMountExtended, { props: { vulnerability } });
      });

      it('does not allow the creation of an additional Jira issue', () => {
        expect(wrapper.findComponent(VulnerabilityActionButtons).props('canCreateIssue')).toBe(
          false,
        );
      });

      it('renders a Jira logo with a tooltip to let the user know that there is an existing issue', () => {
        expect(wrapper.findByTestId('jira-issue-icon').attributes('title')).toBe(
          'Jira Issue Created',
        );
      });

      it('renders a link to the Jira issue that opens in a new tab', () => {
        const jiraIssueLink = wrapper.findByTestId('jira-issue-link');

        expect(jiraIssueLink.props('href')).toBe(
          jiraIssueDetails.external_issue_details.references.web_url,
        );
        expect(jiraIssueLink.attributes('target')).toBe('_blank');
      });
    });
  });

  describe('with a deleted Jira issue', () => {
    const jiraIssueDetails = {
      // when an attached Jira issue gets deleted the external_issue_details is set to null
      external_issue_details: null,
    };

    beforeEach(() => {
      const vulnerability = {
        ...mockDataVulnerabilities[1],
        external_issue_links: [jiraIssueDetails],
        create_jira_issue_url: 'http://jira.example.com',
      };

      createComponent(shallowMountExtended, { props: { vulnerability } });
    });

    it('allows the creation of a Jira issue', () => {
      expect(wrapper.findComponent(VulnerabilityActionButtons).props('canCreateIssue')).toBe(true);
    });

    it('does not render any information about the deleted Jira issue', () => {
      expect(wrapper.findByTestId('jira-issue-icon').exists()).toBe(false);
      expect(wrapper.findByTestId('jira-issue-link').exists()).toBe(false);
    });
  });

  describe('can admin vulnerability', () => {
    it.each([true, false])(
      'shows/hides the select all checkbox if the user can admin vulnerability = %s',
      (canAdminVulnerability) => {
        createComponent(shallowMount, { canAdminVulnerability });

        expect(findCheckbox().exists()).toBe(canAdminVulnerability);
      },
    );
  });
});
