import { GlBadge, GlButton, GlLink, GlSkeletonLoader, GlLoadingIcon } from '@gitlab/ui';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import DependenciesTable from 'ee/dependencies/components/dependencies_table.vue';
import DependencyLicenseLinks from 'ee/dependencies/components/dependency_license_links.vue';
import DependencyVulnerabilities from 'ee/dependencies/components/dependency_vulnerabilities.vue';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import DependencyProjectCount from 'ee/dependencies/components/dependency_project_count.vue';
import DependencyLocation from 'ee/dependencies/components/dependency_location.vue';
import { DEPENDENCIES_TABLE_I18N, NAMESPACE_ORGANIZATION } from 'ee/dependencies/constants';
import stubChildren from 'helpers/stub_children';
import waitForPromises from 'helpers/wait_for_promises';
import { makeDependency } from './utils';

describe('DependenciesTable component', () => {
  let wrapper;
  const vulnerabilityInfo = {
    1: ['bar', 'baz'],
  };

  const basicAppProps = {
    namespaceType: 'project',
    endpoint: 'endpoint',
    locationsEndpoint: 'endpoint',
    belowGroupLimit: true,
  };

  const createComponent = ({ propsData, provide } = {}) => {
    wrapper = mount(DependenciesTable, {
      propsData: { vulnerabilityInfo: {}, ...propsData },
      stubs: {
        ...stubChildren(DependenciesTable),
        GlTable: false,
        DependencyLocation: false,
        DependencyProjectCount: false,
        DependencyLocationCount: false,
      },
      provide: { ...basicAppProps, ...provide },
    });
  };

  const findTableRows = () => wrapper.findAll('tbody > tr');
  const findRowToggleButtons = () => wrapper.findAllComponents(GlButton);
  const findDependencyVulnerabilities = () => wrapper.findComponent(DependencyVulnerabilities);
  const findDependencyLocation = () => wrapper.findComponent(DependencyLocation);
  const findDependencyLocationCount = () => wrapper.findComponent(DependencyLocationCount);
  const findDependencyProjectCount = () => wrapper.findComponent(DependencyProjectCount);
  const findDependencyLicenseLinks = (licenseCell) =>
    licenseCell.findComponent(DependencyLicenseLinks);
  const normalizeWhitespace = (string) => string.replace(/\s+/g, ' ');
  const loadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const sharedExpectations = (rowWrapper, dependency) => {
    const [componentCell, packagerCell, , licenseCell] = rowWrapper.findAll('td').wrappers;

    expect(normalizeWhitespace(componentCell.text())).toBe(
      `${dependency.name} ${dependency.version}`,
    );

    expect(packagerCell.text()).toBe(dependency.packager);

    expect(findDependencyLicenseLinks(licenseCell).props()).toEqual({
      licenses: dependency.licenses,
      title: dependency.name,
    });
  };
  const sharedExpectationsProjectOnly = (rowWrapper, dependency) => {
    sharedExpectations(rowWrapper, dependency);
    const [, , locationCell, , ,] = rowWrapper.findAll('td').wrappers;

    expect(findDependencyLocation().exists()).toBe(true);
    const locationLink = locationCell.findComponent(GlLink);
    expect(locationLink.attributes().href).toBe(dependency.location.blobPath);
    expect(locationLink.text()).toContain(dependency.location.path);

    expect(findDependencyLocationCount().exists()).toBe(false);
    expect(findDependencyProjectCount().exists()).toBe(false);
  };

  const expectDependencyRow = (rowWrapper, dependency) => {
    sharedExpectationsProjectOnly(rowWrapper, dependency);
    const [, , , , isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());

    if (dependency?.vulnerabilities?.length) {
      expect(isVulnerableCellText).toContain(`${dependency.vulnerabilities.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
  };

  const expectDependencyRowWithSbom = (rowWrapper, dependency) => {
    sharedExpectationsProjectOnly(rowWrapper, dependency);
    const [, , , , isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(isVulnerableCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
  };

  const expectGroupDependencyRow = (rowWrapper, dependency) => {
    sharedExpectations(rowWrapper, dependency);
    const [, , locationCell, , projectCell, isVulnerableCell] = rowWrapper.findAll('td').wrappers;

    const {
      occurrenceCount,
      projectCount,
      location: { path },
    } = dependency;
    const locationCellText = occurrenceCount > 1 ? occurrenceCount.toString() : path;

    const isVulnerableCellText = normalizeWhitespace(isVulnerableCell.text());
    const vulns = vulnerabilityInfo[dependency.occurrenceId];

    if (vulns?.length) {
      expect(isVulnerableCellText).toContain(`${vulns.length} vuln`);
    } else {
      expect(isVulnerableCellText).toBe('');
    }
    expect(locationCell.text()).toContain(locationCellText);
    expect(projectCell.text()).toContain(projectCount.toString());
  };

  const expectOrganizationDependencyRow = (rowWrapper, dependency) => {
    const [componentCell, packagerCell, locationCell] = rowWrapper.findAll('td').wrappers;

    expect(normalizeWhitespace(componentCell.text())).toBe(
      `${dependency.name} ${dependency.version}`,
    );

    expect(packagerCell.text()).toBe(dependency.packager);
    expect(locationCell.text()).toContain(dependency.location.path);
  };

  describe('given the table is loading', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [makeDependency()];
      createComponent({
        propsData: {
          dependencies,
          isLoading: true,
        },
      });
    });

    it('renders the loading skeleton', () => {
      expect(wrapper.findComponent(GlSkeletonLoader).exists()).toBe(true);
    });

    it('does not render any dependencies', () => {
      expect(wrapper.text()).not.toContain(dependencies[0].name);
    });
  });

  describe('given an empty list of dependencies', () => {
    describe.each`
      namespaceType | expectedLabels
      ${'project'}  | ${['Component', 'Packager', 'Location', 'License', '' /* the last column has no heading, so the label is just an empty string */]}
      ${'group'}    | ${['Component', 'Packager', 'Location', 'License', 'Projects']}
    `('with namespaceType set to "$namespaceType"', ({ namespaceType, expectedLabels }) => {
      beforeEach(() => {
        createComponent({
          propsData: {
            dependencies: [],
            isLoading: false,
          },
          provide: {
            namespaceType,
          },
        });
      });

      it('renders the table header', () => {
        const headerCells = wrapper.findAll('thead th');

        expectedLabels.forEach((expectedLabel, i) => {
          expect(headerCells.at(i).text()).toContain(expectedLabel);
        });
      });

      it('renders a message that there are no records to show', () => {
        expect(wrapper.text()).toContain('There are no records to show');
      });
    });
  });

  describe.each`
    description                                                             | vulnerabilitiesPayload
    ${'given dependencies with no vulnerabilities'}                         | ${{ vulnerabilities: [] }}
    ${'given dependencies when user is not allowed to see vulnerabilities'} | ${{}}
  `('$description', ({ vulnerabilitiesPayload }) => {
    let dependencies;

    beforeEach(() => {
      dependencies = [
        makeDependency({ ...vulnerabilitiesPayload }),
        makeDependency({ name: 'foo', ...vulnerabilitiesPayload }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();

      dependencies.forEach((dependency, i) => {
        expectDependencyRow(rows.at(i), dependency);
      });
    });

    it('does not render any row toggle buttons', () => {
      expect(findRowToggleButtons()).toHaveLength(0);
    });

    it('does not render vulnerability details', () => {
      expect(findDependencyVulnerabilities().exists()).toBe(false);
    });
  });

  describe.each`
    projectLevelSbomOccurrences | expectedFcn
    ${false}                    | ${expectDependencyRow}
    ${true}                     | ${expectDependencyRowWithSbom}
  `(
    `given some dependencies with vulnerabilities`,
    ({ projectLevelSbomOccurrences, expectedFcn }) => {
      let dependencies;

      beforeEach(() => {
        dependencies = [
          makeDependency({
            name: 'qux',
            vulnerabilities: ['bar', 'baz'],
            vulnerabilityCount: 2,
            occurrenceId: 1,
          }),
          makeDependency({ vulnerabilities: [], vulnerabilityCount: 0, occurrenceId: 2 }),
          // Guarantee that the component doesn't mutate these, but still
          // maintains its row-toggling behaviour (i.e., via _showDetails)
        ].map(Object.freeze);

        createComponent({
          propsData: {
            dependencies,
            isLoading: false,
            vulnerabilityInfo,
          },
          provide: { glFeatures: { projectLevelSbomOccurrences } },
        });
      });

      it('renders a row for each dependency', () => {
        const rows = findTableRows();

        dependencies.forEach((dependency, i) => {
          expectedFcn(rows.at(i), dependency);
        });
      });

      it('render the toggle button for each row', () => {
        const toggleButtons = findRowToggleButtons();

        dependencies.forEach((dependency, i) => {
          const vulnerabilityCount = projectLevelSbomOccurrences
            ? dependency.vulnerabilityCount
            : dependency.vulnerabilities.length;
          const button = toggleButtons.at(i);

          expect(button.exists()).toBe(true);
          expect(button.classes('invisible')).toBe(vulnerabilityCount === 0);
        });
      });

      it('does not render vulnerability details', () => {
        expect(findDependencyVulnerabilities().exists()).toBe(false);
      });

      describe('the dependency vulnerabilities', () => {
        let rowIndexWithVulnerabilities;

        beforeEach(() => {
          rowIndexWithVulnerabilities = dependencies.findIndex(
            (dep) => dep.vulnerabilities.length > 0,
          );
        });

        it('can be displayed by clicking on the toggle button', () => {
          const dependency = dependencies[rowIndexWithVulnerabilities];
          const vulnerabilities = projectLevelSbomOccurrences
            ? vulnerabilityInfo[dependency.occurrenceId]
            : dependency.vulnerabilities;
          const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
          toggleButton.vm.$emit('click');

          return nextTick().then(() => {
            expect(findDependencyVulnerabilities().props()).toEqual({
              vulnerabilities,
            });
          });
        });

        it('can be displayed by clicking on the vulnerabilities badge', () => {
          const dependency = dependencies[rowIndexWithVulnerabilities];
          const vulnerabilities = projectLevelSbomOccurrences
            ? vulnerabilityInfo[dependency.occurrenceId]
            : dependency.vulnerabilities;
          const badge = findTableRows().at(rowIndexWithVulnerabilities).findComponent(GlBadge);
          badge.trigger('click');

          return nextTick().then(() => {
            expect(findDependencyVulnerabilities().props()).toEqual({
              vulnerabilities,
            });
          });
        });

        it('handles row-click event', () => {
          const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
          toggleButton.vm.$emit('click');

          return nextTick().then(() => {
            if (projectLevelSbomOccurrences) {
              expect(wrapper.emitted('row-click')).toHaveLength(1);
            } else {
              expect(wrapper.emitted('row-click')).toBeUndefined();
            }
          });
        });

        it('can display loading icon', async () => {
          const toggleButton = findRowToggleButtons().at(rowIndexWithVulnerabilities);
          toggleButton.vm.$emit('click');

          await waitForPromises();
          const events = wrapper.emitted('row-click');

          if (projectLevelSbomOccurrences) {
            wrapper.setProps({ vulnerabilityItemsLoading: events[0] });
            await waitForPromises();
            expect(loadingIcon().exists()).toBe(true);
          } else {
            expect(events).toBeUndefined();
          }
        });
      });
    },
  );

  describe('with dependencies that do not have an occurrence count', () => {
    let dependencies;

    beforeEach(() => {
      dependencies = [
        makeDependency({
          name: 'actioncable',
          version: '7.0.6',
          packager: 'bundler',
          location: {
            blobPath:
              '/a-group/a-project/-/blob/f67dc4c5466304d6cbe1ecdd18196283447f1a34/Gemfile.lock',
            path: 'Gemfile.lock',
          },
        }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
        provide: { namespaceType: NAMESPACE_ORGANIZATION },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();
      expectOrganizationDependencyRow(rows.at(0), dependencies[0]);
    });
  });

  describe('with multiple dependencies sharing the same componentId', () => {
    let dependencies;
    beforeEach(() => {
      dependencies = [
        makeDependency({
          componentId: 1,
          occurrenceCount: 2,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 2,
        }),
        makeDependency({
          componentId: 1,
          occurrenceCount: 2,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 2,
        }),
        makeDependency({
          componentId: 2,
          occurrenceCount: 1,
          project: { full_path: 'full_path', name: 'name' },
          projectCount: 1,
        }),
      ];

      createComponent({
        propsData: {
          dependencies,
          isLoading: false,
        },
        provide: { namespaceType: 'group' },
      });
    });

    it('renders a row for each dependency', () => {
      const rows = findTableRows();
      expectGroupDependencyRow(rows.at(0), dependencies[0]);
      expectGroupDependencyRow(rows.at(1), dependencies[1]);
      expectGroupDependencyRow(rows.at(2), dependencies[2]);
    });
  });

  describe('when packager is not set', () => {
    beforeEach(() => {
      createComponent({
        propsData: {
          dependencies: [
            makeDependency({
              componentId: 1,
              occurrenceCount: 1,
              project: { full_path: 'full_path', name: 'name' },
              projectCount: 1,
              packager: null,
            }),
          ],
          isLoading: false,
        },
      });
    });

    it('displays unknown', () => {
      const rows = findTableRows();
      const packagerCell = rows.at(0).findAll('td').at(1);

      expect(packagerCell.text()).toBe(DEPENDENCIES_TABLE_I18N.unknown);
    });
  });
});
