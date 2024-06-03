import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlAlert, GlSprintf, GlIcon } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_PROJECT } from '~/graphql_shared/constants';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import waitForPromises from 'helpers/wait_for_promises';
import ScopeSection from 'ee/security_orchestration/components/policy_editor/scope/scope_section.vue';
import ComplianceFrameworkDropdown from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_dropdown.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/group_projects_dropdown.vue';
import LoaderWithMessage from 'ee/security_orchestration/components/loader_with_message.vue';
import ScopeSectionAlert from 'ee/security_orchestration/components/policy_editor/scope/scope_section_alert.vue';
import getSppLinkedProjectsNamespaces from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_namespaces.graphql';
import createMockApollo from 'helpers/mock_apollo_helper';
import {
  PROJECTS_WITH_FRAMEWORK,
  ALL_PROJECTS_IN_GROUP,
  SPECIFIC_PROJECTS,
  EXCEPT_PROJECTS,
  WITHOUT_EXCEPTIONS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import { mockLinkedSppItemsResponse } from 'ee_jest/security_orchestration/mocks/mock_apollo';

describe('PolicyScope', () => {
  let wrapper;
  let requestHandler;

  const createHandler = ({ projects = [], namespaces = [] } = {}) =>
    jest.fn().mockResolvedValue({
      data: {
        project: {
          id: '1',
          securityPolicyProjectLinkedProjects: {
            nodes: projects,
          },
          securityPolicyProjectLinkedNamespaces: {
            nodes: namespaces,
          },
        },
      },
    });

  const createMockApolloProvider = (handler) => {
    Vue.use(VueApollo);
    requestHandler = handler;

    return createMockApollo([[getSppLinkedProjectsNamespaces, requestHandler]]);
  };

  const createComponent = ({
    propsData,
    provide = {},
    handler = mockLinkedSppItemsResponse(),
  } = {}) => {
    wrapper = shallowMountExtended(ScopeSection, {
      apolloProvider: createMockApolloProvider(handler),
      propsData: {
        policyScope: {},
        ...propsData,
      },
      provide: {
        existingPolicy: null,
        namespaceType: NAMESPACE_TYPES.GROUP,
        namespacePath: 'gitlab-org',
        rootNamespacePath: 'gitlab-org-root',
        ...provide,
      },
      stubs: {
        GlSprintf,
        ScopeSectionAlert,
        LoaderWithMessage,
      },
    });
  };

  const findGlAlert = () => wrapper.findComponent(GlAlert);
  const findComplianceFrameworkDropdown = () => wrapper.findComponent(ComplianceFrameworkDropdown);
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);
  const findProjectScopeTypeDropdown = () => wrapper.findByTestId('project-scope-type');
  const findExceptionTypeDropdown = () => wrapper.findByTestId('exception-type');
  const findPolicyScopeProjectText = () => wrapper.findByTestId('policy-scope-project-text');
  const findLoader = () => wrapper.findComponent(LoaderWithMessage);
  const findScopeSectionAlert = () => wrapper.findComponent(ScopeSectionAlert);
  const findLoadingText = () => wrapper.findByTestId('loading-text');
  const findErrorMessage = () => wrapper.findByTestId('policy-scope-project-error');
  const findErrorMessageText = () => wrapper.findByTestId('policy-scope-project-error-text');
  const findDefaultScopeSelector = () => wrapper.findByTestId('default-scope-selector');
  const findIcon = () => wrapper.findComponent(GlIcon);

  beforeEach(() => {
    createComponent();
  });

  it('should render framework dropdown in initial state', () => {
    expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
    expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
    expect(findExceptionTypeDropdown().exists()).toBe(true);
    expect(findExceptionTypeDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);

    expect(findGroupProjectsDropdown().exists()).toBe(false);
    expect(findComplianceFrameworkDropdown().exists()).toBe(false);
    expect(findGlAlert().exists()).toBe(false);
  });

  it('should not check linked items on group level', async () => {
    await waitForPromises();

    expect(findLoader().exists()).toBe(false);
    expect(findProjectScopeTypeDropdown().exists()).toBe(true);
    expect(requestHandler).toHaveBeenCalledTimes(0);
    expect(findPolicyScopeProjectText().exists()).toBe(false);
  });

  it('should change scope and reset it', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

    expect(findComplianceFrameworkDropdown().exists()).toBe(true);

    expect(findExceptionTypeDropdown().exists()).toBe(false);
    expect(findGroupProjectsDropdown().exists()).toBe(false);

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
    ]);

    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    expect(findExceptionTypeDropdown().exists()).toBe(false);
    expect(findGroupProjectsDropdown().exists()).toBe(true);
    expect(wrapper.text()).toBe('Apply this policy to');
    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          compliance_frameworks: [],
        },
      ],
      [
        {
          projects: {
            including: [],
          },
        },
      ],
    ]);
  });

  it('should select excluding projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', ALL_PROJECTS_IN_GROUP);

    expect(findGroupProjectsDropdown().exists()).toBe(false);

    await findExceptionTypeDropdown().vm.$emit('select', EXCEPT_PROJECTS);

    expect(findGroupProjectsDropdown().exists()).toBe(true);

    findGroupProjectsDropdown().vm.$emit('select', [
      { id: convertToGraphQLId(TYPENAME_PROJECT, '1') },
      { id: convertToGraphQLId(TYPENAME_PROJECT, '2') },
    ]);

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            excluding: [],
          },
        },
      ],
      [
        {
          projects: {
            excluding: [],
          },
        },
      ],
      [{ projects: { excluding: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select including projects', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

    expect(findGroupProjectsDropdown().exists()).toBe(true);

    findGroupProjectsDropdown().vm.$emit('select', [
      { id: convertToGraphQLId(TYPENAME_PROJECT, '1') },
      { id: convertToGraphQLId(TYPENAME_PROJECT, '2') },
    ]);

    expect(wrapper.emitted('changed')).toEqual([
      [
        {
          projects: {
            including: [],
          },
        },
      ],
      [{ projects: { including: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('should select compliance frameworks', async () => {
    await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);
    findComplianceFrameworkDropdown().vm.$emit('select', ['id1', 'id2']);

    expect(wrapper.emitted('changed')).toEqual([
      [{ compliance_frameworks: [] }],
      [{ compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }] }],
    ]);
  });

  describe('existing policy scope', () => {
    it('should render existing compliance frameworks', () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [{ id: 'id1' }, { id: 'id2' }],
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(true);
      expect(findComplianceFrameworkDropdown().props('disabled')).toBe(false);
      expect(findComplianceFrameworkDropdown().props('selectedFrameworkIds')).toEqual([
        'id1',
        'id2',
      ]);

      expect(findExceptionTypeDropdown().exists()).toBe(false);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
      expect(wrapper.text()).toBe('Apply this policy to named');
    });

    it('should render existing excluding projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(false);

      expect(findExceptionTypeDropdown().props('selected')).toBe(EXCEPT_PROJECTS);
      expect(findExceptionTypeDropdown().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('state')).toBe(true);
      expect(findGroupProjectsDropdown().props('selected')).toEqual([
        convertToGraphQLId(TYPENAME_PROJECT, 'id1'),
        convertToGraphQLId(TYPENAME_PROJECT, 'id2'),
      ]);
    });

    it('should render existing including projects', () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      expect(findComplianceFrameworkDropdown().exists()).toBe(false);
      expect(findExceptionTypeDropdown().exists()).toBe(false);
      expect(findGroupProjectsDropdown().exists()).toBe(true);
      expect(wrapper.text()).toBe('Apply this policy to');
      expect(findGroupProjectsDropdown().props('selected')).toEqual([
        convertToGraphQLId(TYPENAME_PROJECT, 'id1'),
        convertToGraphQLId(TYPENAME_PROJECT, 'id2'),
      ]);
    });

    it('should render alert message for projects dropdown', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [{ id: 'id1' }, { id: 'id2' }],
            },
          },
        },
      });

      await findGroupProjectsDropdown().vm.$emit('projects-query-error');
      expect(findGlAlert().exists()).toBe(true);
    });

    it('should render alert message for compliance framework dropdown', async () => {
      await findProjectScopeTypeDropdown().vm.$emit('select', PROJECTS_WITH_FRAMEWORK);

      await findComplianceFrameworkDropdown().vm.$emit('framework-query-error');
      expect(findGlAlert().exists()).toBe(true);
    });
  });

  describe('project level', () => {
    describe('security policy project', () => {
      const createComponentForSPP = async ({ provide = {} } = {}) => {
        createComponent({
          provide: {
            namespaceType: NAMESPACE_TYPES.PROJECT,
            ...provide,
          },
          handler: createHandler({
            projects: [
              { id: '1', name: 'name1' },
              { id: '2', name: 'name2 ' },
            ],
            namespaces: [
              { id: '1', name: 'name1' },
              { id: '2', name: 'name2 ' },
            ],
          }),
        });

        await waitForPromises();
      };

      describe('new policy', () => {
        beforeEach(async () => {
          await createComponentForSPP();
        });

        it('does not show the default scope option', () => {
          expect(findDefaultScopeSelector().exists()).toBe(false);
        });

        it('shows the enabled policy scope selector', () => {
          expect(findPolicyScopeProjectText().exists()).toBe(false);
          expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
          expect(findExceptionTypeDropdown().exists()).toBe(true);
        });
      });

      describe('existing policy', () => {
        describe('no existing policy scope', () => {
          beforeEach(async () => {
            await createComponentForSPP({ provide: { existingPolicy: { name: 'A' } } });
          });

          it('displays the default scope and checks it', () => {
            expect(findDefaultScopeSelector().exists()).toBe(true);
            expect(findDefaultScopeSelector().attributes('checked')).toBe('true');
          });

          it('disables the scope dropdowns when default scope is set', () => {
            expect(findProjectScopeTypeDropdown().exists()).toBe(true);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(true);
            expect(findExceptionTypeDropdown().exists()).toBe(true);
            expect(findExceptionTypeDropdown().props('disabled')).toBe(true);
          });

          it('enables the scope dropdowns when default scope is unchecked', async () => {
            await findDefaultScopeSelector().vm.$emit('input', false);
            expect(findProjectScopeTypeDropdown().props('disabled')).toBe(false);
            expect(findExceptionTypeDropdown().props('disabled')).toBe(false);
          });

          it('adds the policy scope yaml when default scope is unchecked', async () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
            await findDefaultScopeSelector().vm.$emit('change');
            expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
          });

          it('does not emit default policy scope on load', () => {
            expect(wrapper.emitted('changed')).toEqual(undefined);
          });

          it('resets the selectors when default scope is checked', async () => {
            await findDefaultScopeSelector().vm.$emit('change');
            await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(SPECIFIC_PROJECTS);
            expect(findExceptionTypeDropdown().exists()).toBe(false);
            await findDefaultScopeSelector().vm.$emit('change', true);
            expect(findProjectScopeTypeDropdown().props('selected')).toBe(ALL_PROJECTS_IN_GROUP);
            expect(findExceptionTypeDropdown().exists()).toBe(true);
          });
        });
      });
    });

    it('should check linked items on project level', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(requestHandler).toHaveBeenCalledWith({ fullPath: 'gitlab-org' });
    });

    it('show text message for project without linked items', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().text()).toBe('Apply this policy to current project.');
    });

    it('show compliance framework selector for projects with links', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1' },
            { id: '2', name: 'name2 ' },
          ],
          namespaces: [
            { id: '1', name: 'name1' },
            { id: '2', name: 'name2 ' },
          ],
        }),
      });

      await waitForPromises();

      expect(findPolicyScopeProjectText().exists()).toBe(false);
      expect(findProjectScopeTypeDropdown().exists()).toBe(true);
      expect(findExceptionTypeDropdown().props('selected')).toBe(WITHOUT_EXCEPTIONS);
    });

    it('shows loading state', () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
      });

      expect(findLoader().exists()).toBe(true);
      expect(findLoadingText().text()).toBe('Fetching the scope information.');
    });

    it('shows error message when spp query fails', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: jest.fn().mockRejectedValue({}),
      });

      await waitForPromises();

      expect(findErrorMessage().exists()).toBe(true);
      expect(findErrorMessageText().text()).toBe(
        'Failed to fetch the scope information. Please refresh the page to try again.',
      );
      expect(findIcon().props('name')).toBe('status_warning');
    });

    it('emits default policy scope on project level for SPP with multiple dependencies', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.PROJECT,
        },
        handler: mockLinkedSppItemsResponse({
          projects: [
            { id: '1', name: 'name1' },
            { id: '2', name: 'name2 ' },
          ],
          namespaces: [
            { id: '1', name: 'name1' },
            { id: '2', name: 'name2 ' },
          ],
        }),
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toEqual([[{ projects: { excluding: [] } }]]);
    });

    it('does not emit default policy scope on group level', async () => {
      createComponent({
        provide: {
          namespaceType: NAMESPACE_TYPES.GROUP,
        },
      });

      await waitForPromises();

      expect(wrapper.emitted('changed')).toBeUndefined();
    });
  });

  describe('namespace', () => {
    it.each`
      namespaceType              | expectedResult
      ${NAMESPACE_TYPES.GROUP}   | ${'gitlab-org'}
      ${NAMESPACE_TYPES.PROJECT} | ${'gitlab-org-root'}
    `(
      'queries different namespaces on group and project level',
      async ({ namespaceType, expectedResult }) => {
        createComponent({
          provide: {
            namespaceType,
          },
          handler: mockLinkedSppItemsResponse({
            projects: [
              { id: '1', name: 'name1' },
              { id: '2', name: 'name2 ' },
            ],
            namespaces: [
              { id: '1', name: 'name1' },
              { id: '2', name: 'name2 ' },
            ],
          }),
        });

        await waitForPromises();
        await findProjectScopeTypeDropdown().vm.$emit('select', SPECIFIC_PROJECTS);

        expect(findGroupProjectsDropdown().props('groupFullPath')).toBe(expectedResult);
      },
    );
  });

  describe('error message and validation', () => {
    const findScopeAlert = () => findScopeSectionAlert().findComponent(GlAlert);

    it('should show alert when compliance frameworks are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            compliance_frameworks: [],
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);
      expect(findComplianceFrameworkDropdown().props('showError')).toBe(false);

      await findComplianceFrameworkDropdown().vm.$emit('select', ['id1']);

      expect(findScopeAlert().exists()).toBe(true);
      expect(findComplianceFrameworkDropdown().props('showError')).toBe(true);
    });

    it('should show alert when specific projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              including: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findGroupProjectsDropdown().vm.$emit('select', ['id1']);

      expect(findScopeAlert().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('state')).toBe(false);
      expect(findScopeSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: true,
        projectEmpty: true,
        projectScopeType: SPECIFIC_PROJECTS,
      });
    });

    it('should show alert when excluding projects are empty', async () => {
      createComponent({
        propsData: {
          policyScope: {
            projects: {
              excluding: [],
            },
          },
        },
      });

      expect(findScopeAlert().exists()).toBe(false);

      await findExceptionTypeDropdown().vm.$emit('select', EXCEPT_PROJECTS);
      await findGroupProjectsDropdown().vm.$emit('select', ['id1']);

      expect(findScopeAlert().exists()).toBe(true);
      expect(findGroupProjectsDropdown().props('state')).toBe(false);

      expect(findScopeSectionAlert().props()).toEqual({
        complianceFrameworksEmpty: true,
        isDirty: true,
        isProjectsWithoutExceptions: false,
        projectEmpty: true,
        projectScopeType: ALL_PROJECTS_IN_GROUP,
      });
    });
  });
});
