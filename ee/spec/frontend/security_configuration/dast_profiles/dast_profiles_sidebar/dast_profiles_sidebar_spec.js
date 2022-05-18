import { nextTick } from 'vue';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import DastProfilesSidebar from 'ee/security_configuration/dast_profiles/dast_profiles_sidebar/dast_profiles_sidebar.vue';
import DastProfilesLoader from 'ee/security_configuration/dast_profiles/components/dast_profiles_loader.vue';
import { scannerProfiles } from 'ee_jest/security_configuration/dast_profiles/mocks/mock_data';
import { SCANNER_TYPE, SITE_TYPE } from 'ee/on_demand_scans/constants';

describe('DastProfilesSidebar', () => {
  let wrapper;
  const projectPath = 'projectPath';

  const createComponent = (options = {}) => {
    wrapper = mountExtended(DastProfilesSidebar, {
      propsData: {
        ...options,
      },
      stubs: {
        GlDrawer: true,
      },
      provide: {
        projectPath,
      },
    });
  };

  const findSidebarHeader = () => wrapper.findByTestId('sidebar-header');
  const findEmptyStateHeader = () => wrapper.findByTestId('empty-state-header');
  const findNewScanButton = () => wrapper.findByTestId('new-profile-button');
  const findEmptyNewScanButton = () => wrapper.findByTestId('new-empty-profile-button');
  const findNewDastScannerProfileForm = () => wrapper.findByTestId('dast-scanner-parent-group');
  const findNewDastSiteProfileForm = () => wrapper.findByTestId('dast-site-parent-group');
  const findCancelButton = () => wrapper.findByTestId('dast-profile-form-cancel-button');
  const findEditButton = () => wrapper.findByTestId('selected-profile-edit-link');
  const findProfileNameInput = () => wrapper.findByTestId('profile-name-input');
  const findSkeletonLoader = () => wrapper.findComponent(DastProfilesLoader);

  afterEach(() => {
    wrapper.destroy();
  });

  it('should show empty state when no scanner profiles exist', () => {
    createComponent({ profileType: 'scanner' });
    expect(findEmptyStateHeader().exists()).toBe(true);
    expect(findEmptyStateHeader().text()).toContain('No scanner profiles found for DAST');
    expect(findSidebarHeader().text()).toContain('Scanner profile library');
  });

  it('should show empty state when no site profiles exist', () => {
    createComponent({ profileType: 'site' });
    expect(findEmptyStateHeader().exists()).toBe(true);
    expect(findEmptyStateHeader().text()).toContain('No site profiles found for DAST');
    expect(findSidebarHeader().text()).toContain('Site profile library');
  });

  it('should render new scan button when profiles exists', () => {
    createComponent({ profiles: scannerProfiles });
    expect(findNewScanButton().exists()).toBe(true);
  });

  it('should hide new scan button when no profiles exists', () => {
    createComponent();

    expect(findNewScanButton().exists()).toBe(false);
  });

  it('should open new scanner profile form from header', async () => {
    createComponent({ profileType: SCANNER_TYPE, profiles: scannerProfiles });
    findNewScanButton().vm.$emit('click');

    await nextTick();

    expect(findNewDastScannerProfileForm().exists()).toBe(true);
    expect(findSidebarHeader().text()).toContain('New scanner profile');
  });

  describe('new profile form', () => {
    it('should show new scanner profile form', async () => {
      createComponent({ profileType: SCANNER_TYPE });
      findEmptyNewScanButton().vm.$emit('click');

      await nextTick();

      expect(findNewDastScannerProfileForm().exists()).toBe(true);
    });

    it('should show new site profile form', async () => {
      createComponent({ profileType: SITE_TYPE });
      findEmptyNewScanButton().vm.$emit('click');

      await nextTick();

      expect(findNewDastSiteProfileForm().exists()).toBe(true);
    });

    it('should close form when cancelled', async () => {
      createComponent({ profileType: SITE_TYPE });
      findEmptyNewScanButton().vm.$emit('click');
      await nextTick();

      findCancelButton().vm.$emit('click');

      await nextTick();

      expect(findEmptyStateHeader().exists()).toBe(true);
    });
  });

  describe('loading state', () => {
    it('should show loaders when loading is in progress', () => {
      createComponent({ isLoading: true });
      expect(findSkeletonLoader().exists()).toBe(true);
    });
  });

  describe('editing mode', () => {
    it('should be possible to edit profile', async () => {
      createComponent({ profileType: SCANNER_TYPE, profiles: scannerProfiles });
      findEditButton().vm.$emit('click');

      await nextTick();

      expect(findProfileNameInput().element.value).toBe(scannerProfiles[0].profileName);
      expect(findNewDastScannerProfileForm().exists()).toBe(true);
      expect(findSidebarHeader().text()).toContain('Edit scanner profile');
    });
  });
});
