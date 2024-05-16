import $ from 'jquery';
import { nextTick } from 'vue';
import { GlToggle, GlButton } from '@gitlab/ui';
import HeaderComponent from '~/vue_shared/components/markdown/header.vue';
import HeaderDividerComponent from '~/vue_shared/components/markdown/header_divider.vue';
import CommentTemplatesModal from '~/vue_shared/components/markdown/comment_templates_modal.vue';
import ToolbarButton from '~/vue_shared/components/markdown/toolbar_button.vue';
import DrawioToolbarButton from '~/vue_shared/components/markdown/drawio_toolbar_button.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { updateText } from '~/lib/utils/text_markdown';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';

jest.mock('~/lib/utils/text_markdown');

describe('Markdown field header component', () => {
  let wrapper;

  const createWrapper = ({ props = {}, provide = {}, attachTo = document.body } = {}) => {
    wrapper = shallowMountExtended(HeaderComponent, {
      attachTo,
      propsData: {
        previewMarkdown: false,
        ...props,
      },
      stubs: { GlToggle },
      provide,
    });
  };

  const findPreviewToggle = () => wrapper.findByTestId('preview-toggle');
  const findToolbar = () => wrapper.findByTestId('md-header-toolbar');
  const findToolbarButtons = () => wrapper.findAllComponents(ToolbarButton);
  const findDividers = () => wrapper.findAllComponents(HeaderDividerComponent);
  const findToolbarButtonByProp = (prop, value) =>
    findToolbarButtons()
      .filter((button) => button.props(prop) === value)
      .at(0);
  const findDrawioToolbarButton = () => wrapper.findComponent(DrawioToolbarButton);
  const findCommentTemplatesModal = () => wrapper.findComponent(CommentTemplatesModal);

  beforeEach(() => {
    window.gl = {
      client: {
        isMac: true,
      },
    };

    createWrapper();
  });

  describe.each`
    i     | buttonTitle                       | nonMacTitle                                | buttonType
    ${0}  | ${'Insert suggestion'}            | ${'Insert suggestion'}                     | ${'codeSuggestion'}
    ${1}  | ${'Add bold text (⌘B)'}           | ${'Add bold text (Ctrl+B)'}                | ${'bold'}
    ${2}  | ${'Add italic text (⌘I)'}         | ${'Add italic text (Ctrl+I)'}              | ${'italic'}
    ${3}  | ${'Add strikethrough text (⌘⇧X)'} | ${'Add strikethrough text (Ctrl+Shift+X)'} | ${'strike'}
    ${4}  | ${'Insert a quote'}               | ${'Insert a quote'}                        | ${'blockquote'}
    ${5}  | ${'Insert code'}                  | ${'Insert code'}                           | ${'code'}
    ${6}  | ${'Add a link (⌘K)'}              | ${'Add a link (Ctrl+K)'}                   | ${'link'}
    ${7}  | ${'Add a bullet list'}            | ${'Add a bullet list'}                     | ${'bulletList'}
    ${8}  | ${'Add a numbered list'}          | ${'Add a numbered list'}                   | ${'orderedList'}
    ${9}  | ${'Add a checklist'}              | ${'Add a checklist'}                       | ${'taskList'}
    ${10} | ${'Indent line (⌘])'}             | ${'Indent line (Ctrl+])'}                  | ${'indent'}
    ${11} | ${'Outdent line (⌘[)'}            | ${'Outdent line (Ctrl+[)'}                 | ${'outdent'}
    ${12} | ${'Add a collapsible section'}    | ${'Add a collapsible section'}             | ${'details'}
    ${13} | ${'Add a table'}                  | ${'Add a table'}                           | ${'table'}
    ${14} | ${'Attach a file or image'}       | ${'Attach a file or image'}                | ${'upload'}
    ${15} | ${'Go full screen'}               | ${'Go full screen'}                        | ${'fullScreen'}
  `('markdown header buttons', ({ i, buttonTitle, nonMacTitle, buttonType }) => {
    it('renders the buttons with the correct title', () => {
      expect(findToolbarButtons().wrappers[i].props('buttonTitle')).toBe(buttonTitle);
    });

    it('renders correct title on non MacOS systems', () => {
      window.gl = { client: { isMac: false } };

      createWrapper();

      expect(findToolbarButtons().wrappers[i].props('buttonTitle')).toBe(nonMacTitle);
    });

    it('passes button type to `trackingProperty` prop', () => {
      expect(findToolbarButtons().wrappers[i].props('trackingProperty')).toBe(buttonType);
    });
  });

  it('attach file button should have data-button-type attribute', () => {
    const attachButton = findToolbarButtonByProp('icon', 'paperclip');

    // Used for dropzone_input.js as `clickable` property
    // to prevent triggers upload file by clicking on the edge of textarea
    expect(attachButton.attributes('data-button-type')).toBe('attach-file');
  });

  it('hides markdown preview when previewMarkdown is false', () => {
    expect(findPreviewToggle().text()).toBe('Preview');
  });

  it('shows markdown preview when previewMarkdown is true', () => {
    createWrapper({ props: { previewMarkdown: true } });

    expect(findPreviewToggle().text()).toBe('Continue editing');
  });

  it('hides toolbar in preview mode', () => {
    createWrapper({ props: { previewMarkdown: true } });

    // only one button is rendered in preview mode
    expect(findToolbar().findAllComponents(GlButton)).toHaveLength(1);
  });

  it('hides divider in preview mode', () => {
    createWrapper({ props: { previewMarkdown: true } });

    expect(findDividers().length).toBe(0);
  });

  it('emits toggle markdown event when clicking preview toggle', async () => {
    findPreviewToggle().vm.$emit('click', true);

    await nextTick();
    expect(wrapper.emitted('showPreview').length).toEqual(1);

    findPreviewToggle().vm.$emit('click', false);

    await nextTick();
    expect(wrapper.emitted('showPreview').length).toEqual(2);
  });

  it('does not emit toggle markdown event when triggered from another form', () => {
    $(document).triggerHandler('markdown-preview:show', [
      $(
        '<form><div class="js-vue-markdown-field"><textarea class="markdown-area"></textarea></div></form>',
      ),
    ]);

    expect(wrapper.emitted('showPreview')).toBeUndefined();
    expect(wrapper.emitted('hidePreview')).toBeUndefined();
  });

  it('renders markdown table template', () => {
    const tableButton = findToolbarButtonByProp('icon', 'table');

    expect(tableButton.props('tag')).toEqual(
      '| header | header |\n| ------ | ------ |\n|        |        |\n|        |        |',
    );
  });

  it('renders suggestion template', () => {
    expect(findToolbarButtonByProp('buttonTitle', 'Insert suggestion').props('tag')).toEqual(
      '```suggestion:-0+0\n{text}\n```',
    );
  });

  it('renders collapsible section template', () => {
    const detailsBlockButton = findToolbarButtonByProp('icon', 'details-block');

    expect(detailsBlockButton.props('tag')).toEqual(
      '<details><summary>Click to expand</summary>\n{text}\n</details>',
    );
  });

  it('does not render suggestion button if `canSuggest` is set to false', () => {
    createWrapper({
      props: {
        canSuggest: false,
      },
    });

    expect(wrapper.find('.js-suggestion-btn').exists()).toBe(false);
  });

  it('hides markdown preview when previewMarkdown property is false', () => {
    createWrapper({
      props: {
        enablePreview: false,
      },
    });

    expect(wrapper.findByTestId('preview-toggle').exists()).toBe(false);
  });

  describe('restricted tool bar items', () => {
    let defaultCount;

    beforeEach(() => {
      defaultCount = findToolbarButtons().length;
    });

    it('restricts items as per input', () => {
      createWrapper({
        props: {
          restrictedToolBarItems: ['quote'],
        },
      });

      expect(findToolbarButtons().length).toBe(defaultCount - 1);
    });

    it('shows all items by default', () => {
      createWrapper();

      expect(findToolbarButtons().length).toBe(defaultCount);
    });

    it("doesn't render dividers when toolbar buttons past them are restricted", () => {
      createWrapper({
        props: {
          enablePreview: false,
          canSuggest: false,
          restrictedToolBarItems: [
            'quote',
            'strikethrough',
            'bullet-list',
            'numbered-list',
            'task-list',
            'collapsible-section',
            'table',
            'attach-file',
            'full-screen',
            'indent',
            'outdent',
          ],
        },
      });
      expect(findDividers().length).toBe(1);
    });
  });

  describe('when drawIOEnabled is true', () => {
    const uploadsPath = '/uploads';
    const markdownPreviewPath = '/preview';

    beforeEach(() => {
      createWrapper({
        props: {
          drawioEnabled: true,
          uploadsPath,
          markdownPreviewPath,
        },
      });
    });

    it('renders drawio toolbar button', () => {
      expect(findDrawioToolbarButton().props()).toEqual({
        uploadsPath,
        markdownPreviewPath,
      });
    });
  });

  describe('when selecting a saved reply from the comment templates dropdown', () => {
    beforeEach(() => {
      setHTMLFixture('<div class="md-area"><textarea></textarea><div id="root"></div></div>');
    });

    afterEach(() => {
      resetHTMLFixture();
    });

    it('updates the textarea with the saved comment', async () => {
      createWrapper({
        attachTo: '#root',
        provide: {
          newCommentTemplatePaths: ['some/path'],
          glFeatures: {
            savedReplies: true,
          },
        },
      });

      await findCommentTemplatesModal().vm.$emit('select', 'Some saved comment');

      expect(updateText).toHaveBeenCalledWith({
        textArea: document.querySelector('textarea'),
        tag: 'Some saved comment',
        cursorOffset: 0,
        wrap: false,
      });
    });

    it('does not show the saved replies button if newCommentTemplatePaths is not defined', () => {
      createWrapper({
        provide: {
          glFeatures: {
            savedReplies: true,
          },
        },
      });

      expect(findCommentTemplatesModal().exists()).toBe(false);
    });
  });
});
