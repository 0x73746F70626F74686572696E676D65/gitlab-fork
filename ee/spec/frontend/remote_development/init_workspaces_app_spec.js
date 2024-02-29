import { escape } from 'lodash';
import { GlEmptyState } from '@gitlab/ui';
import { createWrapper } from '@vue/test-utils';
import { injectVueAppBreadcrumbs } from '~/lib/utils/breadcrumbs';
import { initWorkspacesApp } from 'ee/remote_development/init_workspaces_app';
import WorkspaceList from 'ee/remote_development/pages/list.vue';
import WorkspacesBreadcrumbs from 'ee/remote_development/components/common/workspaces_breadcrumbs.vue';
import { resetHTMLFixture, setHTMLFixture } from 'helpers/fixtures';

jest.mock('~/lib/logger');
jest.mock('~/lib/utils/breadcrumbs');

describe('ee/remote_development/init_workspaces_app', () => {
  let wrapper;

  beforeEach(() => {
    const options = JSON.stringify({
      workspaces_list_path: '/aaa',
      empty_state_svg_path: '/bbb',
    });

    setHTMLFixture(`<div id="js-workspaces" data-options="${escape(options)}"></div>`);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('initWorkspacesApp - integration', () => {
    beforeEach(() => {
      wrapper = createWrapper(initWorkspacesApp());
    });

    it('creates router', () => {
      expect(wrapper.vm.$router.options.base).toBe('/aaa');
    });

    it('renders empty state', () => {
      expect(wrapper.findComponent(GlEmptyState).props('svgPath')).toBe('/bbb');
    });

    it('renders list component', () => {
      const workspaceListComponent = wrapper.findComponent(WorkspaceList);

      expect(workspaceListComponent.exists()).toBe(true);
    });

    it('inits breadcrumbs', () => {
      expect(injectVueAppBreadcrumbs).toHaveBeenCalledWith(
        expect.any(Object),
        WorkspacesBreadcrumbs,
      );
    });
  });

  describe('initWorkspacesApp - when mounting element not found', () => {
    it('returns null', () => {
      document.body.innerHTML = '<div>Look ma! Code!</div>';

      expect(initWorkspacesApp()).toBeNull();
    });
  });
});
