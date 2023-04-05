import { mountExtended } from 'helpers/vue_test_utils_helper';
import ToolbarAttachmentButton from '~/content_editor/components/toolbar_attachment_button.vue';
import Attachment from '~/content_editor/extensions/attachment';
import Link from '~/content_editor/extensions/link';
import { createTestEditor, mockChainedCommands } from '../test_utils';

describe('content_editor/components/toolbar_attachment_button', () => {
  let wrapper;
  let editor;

  const buildWrapper = () => {
    wrapper = mountExtended(ToolbarAttachmentButton, {
      provide: {
        tiptapEditor: editor,
      },
    });
  };

  const selectFile = async (file) => {
    const input = wrapper.findComponent({ ref: 'fileSelector' });

    // override the property definition because `input.files` isn't directly modifyable
    Object.defineProperty(input.element, 'files', { value: [file], writable: true });
    await input.trigger('change');
  };

  beforeEach(() => {
    editor = createTestEditor({
      extensions: [
        Link,
        Attachment.configure({
          renderMarkdown: jest.fn(),
          uploadsPath: '/uploads/',
        }),
      ],
    });

    buildWrapper();
  });

  afterEach(() => {
    editor.destroy();
  });

  it('uploads the selected attachment when file input changes', async () => {
    const commands = mockChainedCommands(editor, ['focus', 'uploadAttachment', 'run']);
    const file = new File(['foo'], 'foo.png', { type: 'image/png' });

    await selectFile(file);

    expect(commands.focus).toHaveBeenCalled();
    expect(commands.uploadAttachment).toHaveBeenCalledWith({ file });
    expect(commands.run).toHaveBeenCalled();

    expect(wrapper.emitted().execute[0]).toEqual([{ contentType: 'link', value: 'upload' }]);
  });
});
