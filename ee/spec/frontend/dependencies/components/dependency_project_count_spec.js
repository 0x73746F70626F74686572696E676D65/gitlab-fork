import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlLink, GlTruncate, GlCollapsibleListbox, GlAvatar } from '@gitlab/ui';
import { shallowMount, mount } from '@vue/test-utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import DependencyProjectCount from 'ee/dependencies/components/dependency_project_count.vue';
import DependencyProjectCountPopover from 'ee/dependencies/components/dependency_project_count_popover.vue';
import dependenciesProjectsQuery from 'ee/dependencies/graphql/projects.query.graphql';
import waitForPromises from 'helpers/wait_for_promises';
import { SEARCH_MIN_THRESHOLD } from 'ee/dependencies/components/constants';

Vue.use(VueApollo);

describe('Dependency Project Count component', () => {
  let wrapper;

  const projectName = 'project-name';
  const fullPath = 'top-level-group/project-name';
  const avatarUrl = 'url/avatar';

  const payload = {
    data: {
      group: {
        id: 1,
        projects: {
          nodes: [
            {
              avatarUrl,
              fullPath,
              id: 2,
              name: projectName,
            },
          ],
        },
      },
    },
  };

  const apolloResolver = jest.fn().mockResolvedValue(payload);

  const createComponent = ({ propsData, mountFn = shallowMount, belowGroupLimit = true } = {}) => {
    const endpoint = 'groups/endpoint/-/dependencies.json';

    const basicProps = {
      projectCount: 1,
      componentId: 1,
    };

    const handlers = [[dependenciesProjectsQuery, apolloResolver]];

    wrapper = mountFn(DependencyProjectCount, {
      apolloProvider: createMockApollo(handlers),
      propsData: { ...basicProps, ...propsData },
      provide: { endpoint, belowGroupLimit },
      stubs: { GlLink, GlTruncate },
    });
  };

  const findProjectLink = () => wrapper.findComponent(GlLink);
  const findProjectAvatar = () => wrapper.findComponent(GlAvatar);
  const findProjectList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findProjectCountPopover = () => wrapper.findComponent(DependencyProjectCountPopover);

  describe('with a single project', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the listbox', () => {
      expect(findProjectList().props()).toMatchObject({
        headerText: '1 project',
        searchable: false,
        items: [],
        loading: false,
        searching: false,
      });
    });
  });

  describe('with multiple projects', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          projectCount: 2,
        },
      });
    });

    it('renders the listbox', () => {
      expect(findProjectList().props()).toMatchObject({
        headerText: '2 projects',
        searchable: false,
        items: [],
        loading: false,
        searching: false,
      });
    });

    describe.each`
      projectCount                | searchable
      ${SEARCH_MIN_THRESHOLD - 1} | ${false}
      ${SEARCH_MIN_THRESHOLD + 1} | ${true}
    `('with project count equal to $projectCount', ({ projectCount, searchable }) => {
      beforeEach(() => {
        createComponent({
          propsData: { projectCount },
        });
      });

      it(`renders listbox with searchable set to ${searchable}`, () => {
        expect(findProjectList().props()).toMatchObject({
          headerText: `${projectCount} projects`,
          searchable,
        });
      });
    });

    describe('with fetched data', () => {
      beforeEach(() => {
        createComponent({
          propsData: {
            projectCount: 2,
          },
          mountFn: mount,
        });
      });

      it('sets searching based on the data being fetched', async () => {
        findProjectList().vm.$emit('shown');
        await waitForPromises();

        expect(apolloResolver).toHaveBeenCalled();
        expect(findProjectList().props('searching')).toBe(false);
      });

      it('sets searching when search term is updated', async () => {
        await findProjectList().vm.$emit('search', 'a');

        expect(findProjectList().props('searching')).toBe(true);

        await waitForPromises();

        expect(findProjectList().props('searching')).toBe(false);
      });

      describe('after the click event', () => {
        beforeEach(async () => {
          findProjectList().vm.$emit('shown');
          await waitForPromises();
        });

        it('displays project avatar', () => {
          expect(findProjectAvatar().props('src')).toBe(avatarUrl);
        });

        it('displays project name', () => {
          expect(findProjectLink().text()).toContain(projectName);
        });

        it('displays link to project dependencies', () => {
          expect(findProjectLink().attributes('href')).toBe(`/${fullPath}/-/dependencies`);
        });

        describe('with relative url root set', () => {
          beforeEach(async () => {
            gon.relative_url_root = '/relative_url';
            createComponent({
              propsData: {
                projectCount: 2,
              },
              mountFn: mount,
            });
            findProjectList().vm.$emit('shown');
            await waitForPromises();
          });

          it('displays link to project dependencies', () => {
            expect(findProjectLink().attributes('href')).toBe(
              `/relative_url/${fullPath}/-/dependencies`,
            );
          });
        });
      });
    });
  });

  describe('with project search location disabled', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          projectCount: 2,
        },
        belowGroupLimit: false,
      });
    });

    it('renders project count popover', () => {
      expect(findProjectCountPopover().props('targetText')).toBe('2 projects');
    });

    it('does not render listbox', () => {
      expect(findProjectList().exists()).toBe(false);
    });

    it('does not render link to project path', () => {
      expect(findProjectLink().exists()).toBe(false);
    });
  });
});
