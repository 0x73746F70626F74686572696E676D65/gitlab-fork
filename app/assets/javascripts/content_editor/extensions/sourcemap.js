import { Extension } from '@tiptap/core';
import Blockquote from './blockquote';
import Bold from './bold';
import BulletList from './bullet_list';
import Code from './code';
import CodeBlockHighlight from './code_block_highlight';
import Heading from './heading';
import HardBreak from './hard_break';
import HorizontalRule from './horizontal_rule';
import Image from './image';
import Italic from './italic';
import Link from './link';
import ListItem from './list_item';
import OrderedList from './ordered_list';
import Paragraph from './paragraph';

export default Extension.create({
  addGlobalAttributes() {
    return [
      {
        types: [
          Bold.name,
          Blockquote.name,
          BulletList.name,
          Code.name,
          CodeBlockHighlight.name,
          HardBreak.name,
          Heading.name,
          HorizontalRule.name,
          Image.name,
          Italic.name,
          Link.name,
          ListItem.name,
          OrderedList.name,
          Paragraph.name,
        ],
        attributes: {
          sourceMarkdown: {
            default: null,
          },
          sourceMapKey: {
            default: null,
          },
        },
      },
    ];
  },
});
