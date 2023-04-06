import { GlBreakpointInstance as bp, breakpoints } from '@gitlab/ui/dist/utils';
import { getCookie, setCookie } from '~/lib/utils/common_utils';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import {
  SIDEBAR_COLLAPSED_CLASS,
  SIDEBAR_COLLAPSED_COOKIE,
  SIDEBAR_COLLAPSED_COOKIE_EXPIRATION,
  toggleSuperSidebarCollapsed,
  initSuperSidebarCollapsedState,
  bindSuperSidebarCollapsedEvents,
  findPage,
  findSidebar,
  findToggle,
} from '~/super_sidebar/super_sidebar_collapsed_state_manager';

const { xl, sm } = breakpoints;

jest.mock('~/lib/utils/common_utils', () => ({
  getCookie: jest.fn(),
  setCookie: jest.fn(),
}));

const pageHasCollapsedClass = (hasClass) => {
  if (hasClass) {
    expect(findPage().classList).toContain(SIDEBAR_COLLAPSED_CLASS);
  } else {
    expect(findPage().classList).not.toContain(SIDEBAR_COLLAPSED_CLASS);
  }
};

describe('Super Sidebar Collapsed State Manager', () => {
  beforeEach(() => {
    setHTMLFixture(`
      <div class="page-with-super-sidebar">
        <aside class="super-sidebar"></aside>
        <button class="js-super-sidebar-toggle"></button>
      </div>
    `);
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  describe('toggleSuperSidebarCollapsed', () => {
    it.each`
      collapsed | saveCookie | windowWidth | hasClass
      ${true}   | ${true}    | ${xl}       | ${true}
      ${true}   | ${false}   | ${xl}       | ${true}
      ${true}   | ${true}    | ${sm}       | ${true}
      ${true}   | ${false}   | ${sm}       | ${true}
      ${false}  | ${true}    | ${xl}       | ${false}
      ${false}  | ${false}   | ${xl}       | ${false}
      ${false}  | ${true}    | ${sm}       | ${false}
      ${false}  | ${false}   | ${sm}       | ${false}
    `(
      'when collapsed is $collapsed, saveCookie is $saveCookie, and windowWidth is $windowWidth then page class contains `page-with-super-sidebar-collapsed` is $hasClass',
      ({ collapsed, saveCookie, windowWidth, hasClass }) => {
        jest.spyOn(bp, 'windowWidth').mockReturnValue(windowWidth);

        toggleSuperSidebarCollapsed(collapsed, saveCookie);

        pageHasCollapsedClass(hasClass);
        expect(findSidebar().inert).toBe(collapsed);

        if (saveCookie && windowWidth >= xl) {
          expect(setCookie).toHaveBeenCalledWith(SIDEBAR_COLLAPSED_COOKIE, collapsed, {
            expires: SIDEBAR_COLLAPSED_COOKIE_EXPIRATION,
          });
        } else {
          expect(setCookie).not.toHaveBeenCalled();
        }
      },
    );

    describe('toggling the super sidebar', () => {
      let sidebar;
      let toggle;

      beforeEach(() => {
        sidebar = findSidebar();
        toggle = findToggle();
        jest.spyOn(toggle, 'focus');
        jest.spyOn(sidebar, 'focus');
      });

      afterEach(() => {
        sidebar = null;
        toggle = null;
      });

      describe('collapsing the sidebar', () => {
        const collapse = true;

        describe('on user action', () => {
          it('hides the sidebar, then focuses the toggle', () => {
            toggleSuperSidebarCollapsed(collapse, false, true);
            jest.runAllTimers();

            expect(sidebar.classList).toContain('gl-visibility-hidden');
            expect(toggle.focus).toHaveBeenCalled();
          });
        });

        describe('on programmatic toggle', () => {
          it('hides the sidebar, but does not focus the toggle', () => {
            toggleSuperSidebarCollapsed(collapse, false, false);
            jest.runAllTimers();

            expect(sidebar.classList).toContain('gl-visibility-hidden');
            expect(toggle.focus).not.toHaveBeenCalled();
          });
        });
      });

      describe('expanding the sidebar', () => {
        const collapse = false;

        describe('on user action', () => {
          it('shows the sidebar, then focuses it', () => {
            toggleSuperSidebarCollapsed(collapse, false, true);

            expect(sidebar.classList).not.toContain('gl-visibility-hidden');
            expect(sidebar.focus).toHaveBeenCalled();
          });
        });

        describe('on programmatic toggle', () => {
          it('shows the sidebar, but does not focus it', () => {
            toggleSuperSidebarCollapsed(collapse, false, false);

            expect(sidebar.classList).not.toContain('gl-visibility-hidden');
            expect(sidebar.focus).not.toHaveBeenCalled();
          });
        });
      });
    });
  });

  describe('initSuperSidebarCollapsedState', () => {
    it.each`
      windowWidth | cookie       | hasClass
      ${xl}       | ${undefined} | ${false}
      ${sm}       | ${undefined} | ${true}
      ${xl}       | ${'true'}    | ${true}
      ${sm}       | ${'true'}    | ${true}
    `(
      'sets page class to `page-with-super-sidebar-collapsed` when windowWidth is $windowWidth and cookie value is $cookie',
      ({ windowWidth, cookie, hasClass }) => {
        jest.spyOn(bp, 'windowWidth').mockReturnValue(windowWidth);
        getCookie.mockReturnValue(cookie);

        initSuperSidebarCollapsedState();

        pageHasCollapsedClass(hasClass);
        expect(setCookie).not.toHaveBeenCalled();
      },
    );
  });

  describe('bindSuperSidebarCollapsedEvents', () => {
    it.each`
      windowWidth | cookie       | hasClass
      ${xl}       | ${undefined} | ${true}
      ${sm}       | ${undefined} | ${true}
      ${xl}       | ${'true'}    | ${false}
      ${sm}       | ${'true'}    | ${false}
    `(
      'toggle click sets page class to `page-with-super-sidebar-collapsed` when windowWidth is $windowWidth and cookie value is $cookie',
      ({ windowWidth, cookie, hasClass }) => {
        setHTMLFixture(`
          <div class="page-with-super-sidebar ${cookie ? SIDEBAR_COLLAPSED_CLASS : ''}">
            <aside class="super-sidebar"></aside>
            <button class="js-super-sidebar-toggle"></button>
          </div>
        `);
        jest.spyOn(bp, 'windowWidth').mockReturnValue(windowWidth);
        getCookie.mockReturnValue(cookie);

        bindSuperSidebarCollapsedEvents();

        findToggle().click();

        pageHasCollapsedClass(hasClass);

        if (windowWidth >= xl) {
          expect(setCookie).toHaveBeenCalledWith(SIDEBAR_COLLAPSED_COOKIE, !cookie, {
            expires: SIDEBAR_COLLAPSED_COOKIE_EXPIRATION,
          });
        } else {
          expect(setCookie).not.toHaveBeenCalled();
        }
      },
    );
  });
});
