import { GlIcon, GlCollapsibleListbox, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import axios from '~/lib/utils/axios_utils';
import waitForPromises from 'helpers/wait_for_promises';
import { HTTP_STATUS_OK } from '~/lib/utils/http_status';
import DependencyLocationCount from 'ee/dependencies/components/dependency_location_count.vue';
import { SEARCH_MIN_THRESHOLD } from 'ee/dependencies/components/constants';

describe('Dependency Location Count component', () => {
  let wrapper;
  let mockAxios;

  const blobPath = '/blob_path/Gemfile.lock';
  const path = 'Gemfile.lock';
  const projectName = 'test-project';
  const endpoint = 'endpoint';
  const unknownPath = 'Unknown path';

  const locationsData = {
    locations: [
      {
        location: {
          blob_path: blobPath,
          path,
        },
        project: {
          name: projectName,
        },
      },
    ],
  };

  const createComponent = ({ propsData, mountFn = shallowMountExtended, ...options } = {}) => {
    wrapper = mountFn(DependencyLocationCount, {
      propsData: {
        ...{
          locationCount: 2,
          componentId: 1,
        },
        ...propsData,
      },
      provide: { locationsEndpoint: endpoint },
      ...options,
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findLocationList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findLocationInfo = () => wrapper.findComponent(GlLink);
  const findUnknownLocationInfo = () => wrapper.findByTestId('unknown-path');
  const findUnknownLocationIcon = () => findUnknownLocationInfo().findComponent(GlIcon);

  beforeEach(() => {
    mockAxios = new MockAdapter(axios);
  });

  afterEach(() => {
    mockAxios.restore();
  });

  it('renders location text and icon', () => {
    createComponent();

    expect(findLocationList().props('headerText')).toBe('2 locations');
    expect(findIcon().props('name')).toBe('doc-text');
  });

  it.each`
    locationCount | headerText
    ${1}          | ${'1 location'}
    ${2}          | ${'2 locations'}
  `(
    'renders correct location text when `locationCount` is $locationCount',
    ({ locationCount, headerText }) => {
      createComponent({
        propsData: {
          locationCount,
        },
      });

      expect(findLocationList().props('headerText')).toBe(headerText);
    },
  );

  it('renders the listbox', () => {
    createComponent();

    expect(findLocationList().props()).toMatchObject({
      headerText: '2 locations',
      searchable: true,
      items: [],
      loading: false,
      searching: true,
    });
  });

  describe('with fetched data', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mountExtended,
      });
      mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, locationsData);
    });

    it('sets searching based on the data being fetched', async () => {
      await findLocationList().vm.$emit('shown');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(mockAxios.history.get).toHaveLength(1);

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('sets searching when search term is updated', async () => {
      await findLocationList().vm.$emit('search', 'a');

      expect(findLocationList().props('searching')).toBe(true);

      await waitForPromises();

      expect(findLocationList().props('searching')).toBe(false);
    });

    it('renders location information', async () => {
      await findLocationList().vm.$emit('shown');
      await waitForPromises();

      expect(findLocationInfo().attributes('href')).toBe(blobPath);
      expect(findLocationInfo().text()).toContain(path);
      expect(wrapper.text()).toContain(projectName);
    });

    describe('with unknown path', () => {
      const unknownPathLocationsData = {
        locations: [
          {
            location: {
              blob_path: null,
              path: null,
            },
            project: {
              name: projectName,
            },
          },
        ],
      };

      beforeEach(() => {
        mockAxios.onGet(endpoint).reply(HTTP_STATUS_OK, unknownPathLocationsData);
      });

      it('renders location information', async () => {
        await findLocationList().vm.$emit('shown');
        await waitForPromises();

        expect(findUnknownLocationIcon().props('name')).toBe('error');
        expect(findUnknownLocationInfo().text()).toContain(unknownPath);
        expect(wrapper.text()).toContain(projectName);
      });
    });

    describe.each`
      locationCount               | searchable
      ${SEARCH_MIN_THRESHOLD - 1} | ${false}
      ${SEARCH_MIN_THRESHOLD + 1} | ${true}
    `('with location count equal to $locationCount', ({ locationCount, searchable }) => {
      beforeEach(() => {
        createComponent({
          propsData: { locationCount },
        });
      });

      it(`renders listbox with searchable set to ${searchable}`, async () => {
        await findLocationList().vm.$emit('shown');
        await waitForPromises();

        expect(findLocationList().props()).toMatchObject({
          headerText: `${locationCount} locations`,
          searchable,
        });
      });
    });
  });
});
