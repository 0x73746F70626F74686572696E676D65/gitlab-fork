import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import { GlButton, GlCollapsibleListbox, GlModal, GlPopover, GlFormGroup } from '@gitlab/ui';
import createMockApollo from 'helpers/mock_apollo_helper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import ComplianceFrameworkDropdown from 'ee/security_orchestration/components/policy_editor/scope/compliance_framework_dropdown.vue';
import ComplianceFrameworkFormModal from 'ee/groups/settings/compliance_frameworks/components/form_modal.vue';
import CreateForm from 'ee/groups/settings/compliance_frameworks/components/create_form.vue';
import SharedForm from 'ee/groups/settings/compliance_frameworks/components/shared_form.vue';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import createComplianceFrameworkMutation from 'ee/groups/settings/compliance_frameworks/graphql/queries/create_compliance_framework.mutation.graphql';
import {
  validCreateResponse,
  mockPageInfo,
} from 'ee_jest/groups/settings/compliance_frameworks/mock_data';
import { stubComponent } from 'helpers/stub_component';
import waitForPromises from 'helpers/wait_for_promises';

describe('ComplianceFrameworkDropdown', () => {
  let wrapper;
  let requestHandlers;

  const showMock = jest.fn();
  const hideMock = jest.fn();
  const openMock = jest.fn();

  const defaultNodes = [
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 1),
      name: 'A1',
      default: true,
      description: 'description 1',
      color: '#cd5b45',
      pipelineConfigurationFullPath: 'path 1',
      projects: { nodes: [] },
    },
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 2),
      name: 'B2',
      default: false,
      description: 'description 2',
      color: '#cd5b45',
      pipelineConfigurationFullPath: 'path 2',
      projects: {
        nodes: [
          {
            id: '1',
            name: 'project-1',
            webUrl: 'gid://gitlab/Project/1',
          },
        ],
      },
    },
    {
      id: convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, 3),
      name: 'a3',
      default: true,
      description: 'description 3',
      color: '#cd5b45',
      pipelineConfigurationFullPath: 'path 3',
      projects: {
        nodes: [
          {
            id: '1',
            name: 'project-1',
            webUrl: 'gid://gitlab/Project/1',
          },
          {
            id: '2',
            name: 'project-2',
            webUrl: 'gid://gitlab/Project/2',
          },
        ],
      },
    },
  ];

  const defaultNodesIds = defaultNodes.map(({ id }) => id);

  const mapItems = (items) =>
    items.map(({ id, name, ...framework }) => ({ value: id, text: name, ...framework }));

  const mockApolloHandlers = (nodes = defaultNodes) => {
    return {
      complianceFrameworks: jest.fn().mockResolvedValue({
        data: {
          namespace: {
            id: 1,
            name: 'name',
            complianceFrameworks: {
              pageInfo: mockPageInfo(),
              nodes,
            },
          },
        },
      }),
      createFrameworkHandler: jest.fn().mockResolvedValue(validCreateResponse),
    };
  };

  const createMockApolloProvider = (handlers) => {
    Vue.use(VueApollo);

    requestHandlers = handlers;
    return createMockApollo([
      [getComplianceFrameworkQuery, requestHandlers.complianceFrameworks],
      [createComplianceFrameworkMutation, requestHandlers.createFrameworkHandler],
    ]);
  };

  const createComponent = ({
    propsData = {},
    handlers = mockApolloHandlers(),
    stubs = {},
  } = {}) => {
    wrapper = shallowMount(ComplianceFrameworkDropdown, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        fullPath: 'gitlab-org',
        ...propsData,
      },
      stubs: {
        GlCollapsibleListbox: stubComponent(GlCollapsibleListbox, {
          template: `<div><slot name="footer"></slot></div>`,
          methods: {
            open: openMock,
          },
        }),
        ComplianceFrameworkFormModal,
        GlModal: stubComponent(GlModal, {
          methods: {
            show: showMock,
            hide: hideMock,
          },
        }),
        ...stubs,
      },
    });
  };

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const findCreateFrameworkButton = () => wrapper.findComponent(GlButton);
  const findGlFormGroup = () => wrapper.findComponent(GlFormGroup);
  const findComplianceFrameworkFormModal = () =>
    wrapper.findComponent(ComplianceFrameworkFormModal);
  const findSharedForm = () => wrapper.findComponent(SharedForm);
  const selectAll = () => findDropdown().vm.$emit('select-all');
  const resetAll = () => findDropdown().vm.$emit('reset');
  const findAllPopovers = () => wrapper.findAllComponents(GlPopover);

  describe('without selected frameworks', () => {
    beforeEach(() => {
      createComponent();
    });

    it('should render loading state', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('should load compliance framework', async () => {
      await waitForPromises();
      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('items')).toEqual(mapItems(defaultNodes));
    });

    it('should select framework ids', async () => {
      const [{ id }] = defaultNodes;

      await waitForPromises();
      findDropdown().vm.$emit('select', [id]);
      expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(id)]]]);
    });

    it('should select all frameworks', async () => {
      await waitForPromises();
      selectAll();
      expect(wrapper.emitted('select')).toEqual([
        [defaultNodesIds.map((id) => getIdFromGraphQLId(id))],
      ]);
    });

    it('renders default text when loading', () => {
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });

    it('should search frameworks despite case', async () => {
      await waitForPromises();

      expect(findDropdown().props('items')).toHaveLength(3);

      await findDropdown().vm.$emit('search', 'a');
      expect(findDropdown().props('items')).toEqual(mapItems([defaultNodes[0], defaultNodes[2]]));
      expect(findDropdown().props('items')).toHaveLength(2);
    });

    it('should render framework create form', () => {
      findCreateFrameworkButton().vm.$emit('click');

      expect(showMock).toHaveBeenCalled();
      findComplianceFrameworkFormModal().vm.$emit('change');

      expect(hideMock).toHaveBeenCalled();
      expect(openMock).toHaveBeenCalled();
    });
  });

  describe('popover with project list', () => {
    it('renders popover with projects list', async () => {
      createComponent({
        stubs: {
          GlCollapsibleListbox,
        },
      });

      await waitForPromises();

      expect(findAllPopovers().at(0).props('title')).toBe('A1 has 0 projects');
      expect(findAllPopovers().at(0).attributes('content')).toBe(
        'Compliance framework has no projects',
      );

      expect(findAllPopovers().at(1).props('title')).toBe('B2 has 1 project');
      expect(findAllPopovers().at(1).attributes('content')).toBe('project-1');

      expect(findAllPopovers().at(2).props('title')).toBe('a3 has 2 projects');
      expect(findAllPopovers().at(2).attributes('content')).toBe('project-1, project-2');
    });
  });

  describe('create new framework', () => {
    it('re-fetches compliance frameworks when a new one is created', async () => {
      createComponent({
        stubs: {
          CreateForm,
        },
      });
      expect(requestHandlers.complianceFrameworks).toHaveBeenCalledTimes(1);

      findCreateFrameworkButton().vm.$emit('click');
      findSharedForm().vm.$emit('submit');

      await waitForPromises();

      expect(showMock).toHaveBeenCalled();
      expect(requestHandlers.complianceFrameworks).toHaveBeenCalledTimes(2);
      expect(requestHandlers.complianceFrameworks).toHaveBeenNthCalledWith(2, {
        fullPath: 'gitlab-org',
      });
    });
  });

  describe('compliance framework list is empty', () => {
    it('renders default text when no frameworks were fetched', async () => {
      createComponent({
        handlers: mockApolloHandlers([]),
      });
      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });
  });

  describe('selected frameworks', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          selectedFrameworkIds: defaultNodesIds,
        },
      });
    });

    it('should be possible to preselect frameworks', async () => {
      await waitForPromises();
      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });

    it('renders all frameworks selected text', async () => {
      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('A1, B2 +1 more');
    });

    it('should reset all frameworks', async () => {
      await waitForPromises();
      resetAll();

      expect(wrapper.emitted('select')).toEqual([[[]]]);
    });
  });

  describe('selected frameworks that does not exist', () => {
    it('renders default placeholder when selected frameworks do not exist', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe('Select compliance frameworks');
    });

    it('filters selected frameworks that does not exist', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: ['one', 'two'],
        },
      });

      await waitForPromises();
      findDropdown().vm.$emit('select', [defaultNodesIds[0]]);

      expect(wrapper.emitted('select')).toEqual([[[getIdFromGraphQLId(defaultNodesIds[0])]]]);
    });
  });

  describe('one selected project', () => {
    it('should render text for selected framework', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: [defaultNodesIds[0]],
        },
      });

      await waitForPromises();
      expect(findDropdown().props('toggleText')).toBe(defaultNodes[0].name);
    });
  });

  describe('when the fetch query throws an error', () => {
    it('emits an error event', async () => {
      createComponent({
        handlers: {
          complianceFrameworks: jest.fn().mockRejectedValue({}),
        },
      });
      await waitForPromises();
      expect(wrapper.emitted('framework-query-error')).toHaveLength(1);
    });
  });

  describe('error state', () => {
    it.each`
      showError | variant      | category       | groupErrorAttribute
      ${false}  | ${'default'} | ${'primary'}   | ${'true'}
      ${true}   | ${'danger'}  | ${'secondary'} | ${null}
    `(
      `should render variant $variant and category $category when showError is $showError`,
      ({ showError, variant, category, groupErrorAttribute }) => {
        createComponent({
          propsData: {
            showError,
          },
        });

        expect(findGlFormGroup().element.getAttribute('state')).toBe(groupErrorAttribute);
        expect(findDropdown().props('variant')).toBe(variant);
        expect(findDropdown().props('category')).toBe(category);
      },
    );
  });

  describe('full id format', () => {
    it('should emit full format of id', async () => {
      createComponent({
        propsData: {
          useShortIdFormat: false,
        },
      });

      await waitForPromises();
      selectAll();

      expect(wrapper.emitted('select')).toEqual([[defaultNodesIds]]);
    });

    it('should render selected ids in full format', async () => {
      createComponent({
        propsData: {
          selectedFrameworkIds: defaultNodesIds,
          useShortIdFormat: false,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(defaultNodesIds);
    });
  });
});
