import { GlTable } from '@gitlab/ui';

import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/projects_section.vue';

import { mountExtended } from 'helpers/vue_test_utils_helper';

import { createFramework } from '../../../../mock_data';

describe('Basic information section', () => {
  let wrapper;

  const framework = createFramework({ id: 1, projects: 3 });
  const projects = framework.projects.nodes;
  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');

  function createComponent() {
    return mountExtended(ProjectsSection, {
      propsData: {
        complianceFramework: framework,
      },
    });
  }

  describe('when loaded', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('correctly displays title', () => {
      expect(wrapper.text()).toContain('Total projects linked to framework: 3');
    });

    it('correctly calculates projects', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(3);
    });

    it.each(Object.keys(projects))('has the correct data for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d.text());
      expect(frameworkProjects[0]).toMatch(projects[idx].name);
      expect(frameworkProjects[1]).toMatch(projects[idx].description);
    });
  });
});
