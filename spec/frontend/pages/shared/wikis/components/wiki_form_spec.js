import { nextTick } from 'vue';
import { GlAlert, GlButton, GlFormInput, GlFormGroup, GlCollapsibleListbox } from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import axios from 'axios';
import MockAdapter from 'axios-mock-adapter';
import { mockTracking } from 'helpers/tracking_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import WikiForm from '~/pages/shared/wikis/components/wiki_form.vue';
import WikiTemplate from '~/pages/shared/wikis/components/wiki_template.vue';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import { WIKI_FORMAT_LABEL, WIKI_FORMAT_UPDATED_ACTION } from '~/pages/shared/wikis/constants';
import { DRAWIO_ORIGIN } from 'spec/test_constants';
import { mockLocation, restoreLocation } from '../test_utils';

jest.mock('~/emoji');
jest.mock('~/lib/graphql');

describe('WikiForm', () => {
  let wrapper;
  let mock;
  let trackingSpy;

  const findForm = () => wrapper.find('form');
  const findTitle = () => wrapper.find('#wiki_title');
  const findFormat = () => wrapper.find('#wiki_format');
  const findMessage = () => wrapper.find('#wiki_message');
  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findSubmitButton = () => wrapper.findByTestId('wiki-submit-button');
  const findCancelButton = () => wrapper.findByTestId('wiki-cancel-button');
  const findTitleHelpLink = () => wrapper.findByText('Learn more.');
  const findMarkdownHelpLink = () => wrapper.findByTestId('wiki-markdown-help-link');
  const findTemplatesDropdown = () => wrapper.findComponent(WikiTemplate);

  const setFormat = (value) => {
    const format = findFormat();

    return format.find(`option[value=${value}]`).setSelected();
  };

  const triggerFormSubmit = async () => {
    findForm().element.dispatchEvent(new Event('submit'));

    await nextTick();
  };

  const pageInfoNew = {
    persisted: false,
    uploadsPath: '/project/path/-/wikis/attachments',
    wikiPath: '/project/path/-/wikis',
    helpPath: '/help/user/project/wiki/index',
    markdownHelpPath: '/help/user/markdown',
    markdownPreviewPath: '/project/path/-/wikis/.md/preview-markdown',
    createPath: '/project/path/-/wikis/new',
  };

  const pageInfoPersisted = {
    ...pageInfoNew,
    persisted: true,
    title: 'My page',
    content: '  My page content  ',
    format: 'markdown',
    path: '/project/path/-/wikis/home',
  };

  const formatOptions = {
    Markdown: 'markdown',
    RDoc: 'rdoc',
    AsciiDoc: 'asciidoc',
    Org: 'org',
  };
  function createWrapper({
    mountFn = shallowMount,
    persisted = false,
    pageInfo,
    glFeatures = { wikiSwitchBetweenContentEditorRawMarkdown: false },
    provide = { drawioUrl: null },
    templates = [],
  } = {}) {
    wrapper = extendedWrapper(
      mountFn(WikiForm, {
        provide: {
          templates,
          formatOptions,
          glFeatures,
          pageInfo: {
            ...(persisted ? pageInfoPersisted : pageInfoNew),
            ...pageInfo,
          },
          deleteWikiUrl: '',
          pageTitle: '',
          csrfToken: '',
          pagePersisted: false,
          ...provide,
        },
        stubs: {
          GlAlert,
          GlButton,
          GlFormInput,
          GlFormGroup,
        },
        mocks: {
          $apollo: {
            queries: {
              currentUser: {
                loading: false,
              },
            },
          },
        },
      }),
    );
  }

  beforeEach(() => {
    trackingSpy = mockTracking(undefined, null, jest.spyOn);
    mock = new MockAdapter(axios);
  });

  afterEach(() => {
    mock.restore();
  });

  it('displays markdown editor', () => {
    createWrapper({ persisted: true });

    const markdownEditor = findMarkdownEditor();

    expect(markdownEditor.props()).toEqual(
      expect.objectContaining({
        value: pageInfoPersisted.content,
        renderMarkdownPath: pageInfoPersisted.markdownPreviewPath,
        uploadsPath: pageInfoPersisted.uploadsPath,
        autofocus: pageInfoPersisted.persisted,
        markdownDocsPath: pageInfoPersisted.markdownHelpPath,
      }),
    );

    expect(markdownEditor.props('formFieldProps')).toMatchObject({
      id: 'wiki_content',
      name: 'wiki[content]',
    });
  });

  it('empties the title field if random_title=true is set in the URL', () => {
    mockLocation('http://gitlab.com/gitlab-org/gitlab/-/wikis/new?random_title=true');

    createWrapper({ persisted: true, mountFn: mount });

    expect(findTitle().element.value).toBe('');

    restoreLocation();
  });

  describe('when wiki page is a template', () => {
    beforeEach(() => {
      mockLocation('http://gitlab.com/gitlab-org/gitlab/-/wikis/templates/abc');
    });

    afterEach(() => {
      restoreLocation();
    });

    it('makes sure commit message includes "Create template" for a new page', async () => {
      createWrapper({ persisted: false, mountFn: mount });

      await findTitle().setValue('my page');

      expect(findMessage().element.value).toBe('Create template my page');
    });

    it('makes sure commit message includes "Update template" for an existing page', async () => {
      createWrapper({ persisted: true, mountFn: mount });

      await findTitle().setValue('my page');

      expect(findMessage().element.value).toBe('Update template my page');
    });

    it('does not show any help text for title', () => {
      createWrapper({ persisted: true });

      expect(wrapper.text()).not.toContain(
        'You can move this page by adding the path to the beginning of the title.',
      );
      expect(wrapper.text()).not.toContain(
        'You can specify the full path for the new file. We will automatically create any missing directories.',
      );
    });

    it('does not show templates dropdown', () => {
      createWrapper({ persisted: true });

      expect(findTemplatesDropdown().exists()).toBe(false);
    });

    it('shows placeholder for title field', () => {
      createWrapper({ persisted: true });

      expect(findTitle().attributes('placeholder')).toBe('Template title');
    });

    it('disables file attachments', () => {
      createWrapper({ persisted: true });

      expect(findMarkdownEditor().props('disableAttachments')).toBe(true);
    });
  });

  describe('templates dropdown', () => {
    const templates = [
      { title: 'Markdown template 1', format: 'markdown', path: '/project/path/-/wikis/template1' },
      { title: 'Markdown template 2', format: 'markdown', path: '/project/path/-/wikis/template2' },
      { title: 'Rdoc template', format: 'rdoc', path: '/project/path/-/wikis/template3' },
      { title: 'Asciidoc template', format: 'asciidoc', path: '/project/path/-/wikis/template4' },
      { title: 'Org template', format: 'org', path: '/project/path/-/wikis/template5' },
    ];

    it('shows the dropdown when page is not a template', () => {
      createWrapper({ templates, mountFn: mount });

      expect(findTemplatesDropdown().exists()).toBe(true);
    });

    it('does not show templates dropdown if no templates to show', () => {
      createWrapper({ mountFn: mount });

      expect(findTemplatesDropdown().exists()).toBe(false);
    });

    it.each`
      format        | visibleTemplates
      ${'markdown'} | ${['Markdown template 1', 'Markdown template 2']}
      ${'rdoc'}     | ${['Rdoc template']}
      ${'asciidoc'} | ${['Asciidoc template']}
      ${'org'}      | ${['Org template']}
    `('shows appropriate templates for format $format', async ({ format, visibleTemplates }) => {
      createWrapper({ templates, mountFn: mount });

      await setFormat(format);

      expect(
        findTemplatesDropdown()
          .findComponent(GlCollapsibleListbox)
          .props('items')
          .map(({ text }) => text),
      ).toEqual(visibleTemplates);
    });
  });

  it.each`
    title                | persisted | message
    ${'my page'}         | ${false}  | ${'Create my page'}
    ${'my-page'}         | ${false}  | ${'Create my page'}
    ${'somedir/my-page'} | ${false}  | ${'Create somedir/my page'}
    ${'my-page'}         | ${true}   | ${'Update my page'}
  `(
    'updates the commit message to $message when title is $title and persisted=$persisted',
    async ({ title, message, persisted }) => {
      createWrapper({ persisted, mountFn: mount });

      await findTitle().setValue(title);

      expect(findMessage().element.value).toBe(message);
    },
  );

  it('sets the commit message to "Update My page" when the page first loads when persisted', async () => {
    createWrapper({ persisted: true, mountFn: mount });

    await nextTick();

    expect(findMessage().element.value).toBe('Update My page');
  });

  it('does not trim page content by default', () => {
    createWrapper({ persisted: true });

    expect(findMarkdownEditor().props().value).toBe('  My page content  ');
  });

  it.each`
    format        | enabled  | action
    ${'markdown'} | ${true}  | ${'displays'}
    ${'rdoc'}     | ${false} | ${'hides'}
    ${'asciidoc'} | ${false} | ${'hides'}
    ${'org'}      | ${false} | ${'hides'}
  `('$action preview in the markdown field when format is $format', async ({ format, enabled }) => {
    createWrapper({ mountFn: mount });

    await setFormat(format);

    expect(findMarkdownEditor().vm.$attrs['enable-preview']).toBe(enabled);
  });

  it.each`
    value         | text
    ${'markdown'} | ${'[Link Title](page-slug)'}
    ${'rdoc'}     | ${'{Link title}[link:page-slug]'}
    ${'asciidoc'} | ${'link:page-slug[Link title]'}
    ${'org'}      | ${'[[page-slug]]'}
  `('updates the link help message when format=$value is selected', async ({ value, text }) => {
    createWrapper({ mountFn: mount });

    await setFormat(value);

    expect(wrapper.text()).toContain(text);
  });

  it.each`
    persisted | titleHelpText                                                                                              | titleHelpLink
    ${true}   | ${'You can move this page by adding the path to the beginning of the title.'}                              | ${'/help/user/project/wiki/index#move-a-wiki-page'}
    ${false}  | ${'You can specify the full path for the new file. We will automatically create any missing directories.'} | ${'/help/user/project/wiki/index#create-a-new-wiki-page'}
  `(
    'shows appropriate title help text and help link for when persisted=$persisted',
    ({ persisted, titleHelpLink, titleHelpText }) => {
      createWrapper({ persisted });

      expect(wrapper.text()).toContain(titleHelpText);
      expect(findTitleHelpLink().attributes().href).toBe(titleHelpLink);
    },
  );

  it('shows correct link for wiki specific markdown docs', () => {
    createWrapper({ mountFn: mount });

    expect(findMarkdownHelpLink().attributes().href).toBe(
      '/help/user/markdown#wiki-specific-markdown',
    );
  });

  describe('when wiki content is updated', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mount, persisted: true });

      await findMarkdownEditor().vm.$emit('input', ' Lorem ipsum dolar sit! ');
    });

    describe('form submit', () => {
      beforeEach(async () => {
        await triggerFormSubmit();
      });

      it('triggers wiki format tracking event', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'wiki_format_updated', {
          extra: {
            old_format: 'markdown',
            project_path: '/project/path/-/wikis/home',
            value: 'markdown',
          },
          label: 'wiki_format',
        });
      });

      it('tracks editor type used', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'save_markdown', {
          label: 'markdown_editor',
          property: 'Wiki',
        });
      });

      it('does not trim page content', () => {
        expect(findMarkdownEditor().props().value).toBe(' Lorem ipsum dolar sit! ');
      });
    });
  });

  describe('submit button state', () => {
    it.each`
      title          | content        | buttonState   | disabledAttr
      ${'something'} | ${'something'} | ${'enabled'}  | ${false}
      ${''}          | ${'something'} | ${'disabled'} | ${true}
      ${'something'} | ${''}          | ${'disabled'} | ${false}
      ${''}          | ${''}          | ${'disabled'} | ${true}
    `(
      "when title='$title', content='$content', then the button is $buttonState'",
      async ({ title, content, disabledAttr }) => {
        createWrapper({ mountFn: mount });

        await findTitle().setValue(title);
        await findMarkdownEditor().vm.$emit('input', content);

        expect(findSubmitButton().props().disabled).toBe(disabledAttr);
      },
    );

    it.each`
      persisted | buttonLabel
      ${true}   | ${'Save changes'}
      ${false}  | ${'Create page'}
    `('when persisted=$persisted, label is set to $buttonLabel', ({ persisted, buttonLabel }) => {
      createWrapper({ persisted });

      expect(findSubmitButton().text()).toBe(buttonLabel);
    });
  });

  describe('cancel button state', () => {
    it.each`
      persisted | redirectLink
      ${false}  | ${'/project/path/-/wikis'}
      ${true}   | ${'/project/path/-/wikis/home'}
    `(
      'when persisted=$persisted, redirects the user to appropriate path',
      ({ persisted, redirectLink }) => {
        createWrapper({ persisted });

        expect(findCancelButton().attributes().href).toBe(redirectLink);
      },
    );
  });

  it.each`
    format        | enabled  | action
    ${'markdown'} | ${true}  | ${'enables'}
    ${'rdoc'}     | ${false} | ${'disables'}
    ${'asciidoc'} | ${false} | ${'disables'}
    ${'org'}      | ${false} | ${'disables'}
  `('$action content editor when format is $format', async ({ format, enabled }) => {
    createWrapper({ mountFn: mount });

    setFormat(format);

    await nextTick();

    expect(findMarkdownEditor().props().enableContentEditor).toBe(enabled);
  });

  describe('when markdown editor activates the content editor', () => {
    beforeEach(async () => {
      createWrapper({ mountFn: mount, persisted: true });

      await findMarkdownEditor().vm.$emit('contentEditor');
    });

    it('disables the format dropdown', () => {
      expect(findFormat().element.getAttribute('disabled')).toBeDefined();
    });

    describe('when triggering form submit', () => {
      const updatedMarkdown = 'hello **world**';

      beforeEach(async () => {
        findMarkdownEditor().vm.$emit('input', updatedMarkdown);
        await triggerFormSubmit();
      });

      it('triggers tracking events on form submit', () => {
        expect(trackingSpy).toHaveBeenCalledWith(undefined, WIKI_FORMAT_UPDATED_ACTION, {
          label: WIKI_FORMAT_LABEL,
          extra: {
            value: findFormat().element.value,
            old_format: pageInfoPersisted.format,
            project_path: pageInfoPersisted.path,
          },
        });
      });
    });
  });

  describe('when drawioURL is provided', () => {
    it('enables drawio editor in the Markdown Editor', () => {
      createWrapper({ provide: { drawioUrl: DRAWIO_ORIGIN } });

      expect(findMarkdownEditor().props().drawioEnabled).toBe(true);
    });
  });

  describe('when drawioURL is empty', () => {
    it('disables drawio editor in the Markdown Editor', () => {
      createWrapper();

      expect(findMarkdownEditor().props().drawioEnabled).toBe(false);
    });
  });
});
