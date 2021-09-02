import { mount } from '@vue/test-utils';
import katex from 'katex';
import Vue from 'vue';
import MarkdownComponent from '~/notebook/cells/markdown.vue';

const Component = Vue.extend(MarkdownComponent);

window.katex = katex;

function buildCellComponent(cell, relativePath = '') {
  return mount(Component, {
    propsData: {
      cell,
    },
    provide: {
      relativeRawPath: relativePath,
    },
  }).vm;
}

function buildMarkdownComponent(markdownContent, relativePath = '') {
  return buildCellComponent(
    {
      cell_type: 'markdown',
      metadata: {},
      source: markdownContent,
    },
    relativePath,
  );
}

describe('Markdown component', () => {
  let vm;
  let cell;
  let json;

  beforeEach(() => {
    json = getJSONFixture('blob/notebook/basic.json');

    // eslint-disable-next-line prefer-destructuring
    cell = json.cells[1];

    vm = buildCellComponent(cell);

    return vm.$nextTick();
  });

  it('does not render prompt', () => {
    expect(vm.$el.querySelector('.prompt span')).toBeNull();
  });

  it('does not render the markdown text', () => {
    expect(vm.$el.querySelector('.markdown').innerHTML.trim()).not.toEqual(cell.source.join(''));
  });

  it('renders the markdown HTML', () => {
    expect(vm.$el.querySelector('.markdown h1')).not.toBeNull();
  });

  it('sanitizes Markdown output', async () => {
    Object.assign(cell, {
      source: [
        '[XSS](data:text/html;base64,PHNjcmlwdD5hbGVydChkb2N1bWVudC5kb21haW4pPC9zY3JpcHQ+Cg==)\n',
      ],
    });

    await vm.$nextTick();
    expect(vm.$el.querySelector('a').getAttribute('href')).toBeNull();
  });

  it('sanitizes HTML', async () => {
    const findLink = () => vm.$el.querySelector('.xss-link');
    Object.assign(cell, {
      source: ['<a href="test.js" data-remote=true data-type="script" class="xss-link">XSS</a>\n'],
    });

    await vm.$nextTick();
    expect(findLink().getAttribute('data-remote')).toBe(null);
    expect(findLink().getAttribute('data-type')).toBe(null);
  });

  describe('When parsing images', () => {
    it.each([
      [
        'for relative images in root folder, it does',
        '![](local_image.png)\n',
        'src="/raw/local_image',
      ],
      [
        'for relative images in child folders, it does',
        '![](data/local_image.png)\n',
        'src="/raw/data',
      ],
      ["for embedded images, it doesn't", '![](data:image/jpeg;base64)\n', 'src="data:'],
      ["for images urls, it doesn't", '![](http://image.png)\n', 'src="http:'],
    ])('%s', async ([testMd, mustContain]) => {
      vm = buildMarkdownComponent([testMd], '/raw/');

      await vm.$nextTick();

      expect(vm.$el.innerHTML).toContain(mustContain);
    });
  });

  describe('tables', () => {
    beforeEach(() => {
      json = getJSONFixture('blob/notebook/markdown-table.json');
    });

    it('renders images and text', () => {
      vm = buildCellComponent(json.cells[0]);

      return vm.$nextTick().then(() => {
        const images = vm.$el.querySelectorAll('img');
        expect(images.length).toBe(5);

        const columns = vm.$el.querySelectorAll('td');
        expect(columns.length).toBe(6);

        expect(columns[0].textContent).toEqual('Hello ');
        expect(columns[1].textContent).toEqual('Test ');
        expect(columns[2].textContent).toEqual('World ');
        expect(columns[3].textContent).toEqual('Fake ');
        expect(columns[4].textContent).toEqual('External image: ');
        expect(columns[5].textContent).toEqual('Empty');

        expect(columns[0].innerHTML).toContain('<img src="data:image/jpeg;base64');
        expect(columns[1].innerHTML).toContain('<img src="data:image/png;base64');
        expect(columns[2].innerHTML).toContain('<img src="data:image/jpeg;base64');
        expect(columns[3].innerHTML).toContain('<img>');
        expect(columns[4].innerHTML).toContain('<img src="https://www.google.com/');
      });
    });
  });

  describe('katex', () => {
    beforeEach(() => {
      json = getJSONFixture('blob/notebook/math.json');
    });

    it('renders multi-line katex', async () => {
      vm = buildCellComponent(json.cells[0]);

      await vm.$nextTick();
      expect(vm.$el.querySelector('.katex')).not.toBeNull();
    });

    it('renders inline katex', async () => {
      vm = buildCellComponent(json.cells[1]);

      await vm.$nextTick();
      expect(vm.$el.querySelector('p:first-child .katex')).not.toBeNull();
    });

    it('renders multiple inline katex', async () => {
      vm = buildCellComponent(json.cells[1]);

      await vm.$nextTick();
      expect(vm.$el.querySelectorAll('p:nth-child(2) .katex')).toHaveLength(4);
    });

    it('output cell in case of katex error', async () => {
      vm = buildMarkdownComponent(['Some invalid $a & b$ inline formula $b & c$\n', '\n']);

      await vm.$nextTick();
      // expect one paragraph with no katex formula in it
      expect(vm.$el.querySelectorAll('p')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('p .katex')).toHaveLength(0);
    });

    it('output cell and render remaining formula in case of katex error', async () => {
      vm = buildMarkdownComponent([
        'An invalid $a & b$ inline formula and a vaild one $b = c$\n',
        '\n',
      ]);

      await vm.$nextTick();
      // expect one paragraph with no katex formula in it
      expect(vm.$el.querySelectorAll('p')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('p .katex')).toHaveLength(1);
    });

    it('renders math formula in list object', async () => {
      vm = buildMarkdownComponent(["- list with inline $a=2$ inline formula $a' + b = c$\n", '\n']);

      await vm.$nextTick();
      // expect one list with a katex formula in it
      expect(vm.$el.querySelectorAll('li')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('li .katex')).toHaveLength(2);
    });

    it("renders math formula with tick ' in it", async () => {
      vm = buildMarkdownComponent(["- list with inline $a=2$ inline formula $a' + b = c$\n", '\n']);

      await vm.$nextTick();
      // expect one list with a katex formula in it
      expect(vm.$el.querySelectorAll('li')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('li .katex')).toHaveLength(2);
    });

    it('renders math formula with less-than-operator < in it', async () => {
      vm = buildMarkdownComponent(['- list with inline $a=2$ inline formula $a + b < c$\n', '\n']);

      await vm.$nextTick();
      // expect one list with a katex formula in it
      expect(vm.$el.querySelectorAll('li')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('li .katex')).toHaveLength(2);
    });

    it('renders math formula with greater-than-operator > in it', async () => {
      vm = buildMarkdownComponent(['- list with inline $a=2$ inline formula $a + b > c$\n', '\n']);

      await vm.$nextTick();
      // expect one list with a katex formula in it
      expect(vm.$el.querySelectorAll('li')).toHaveLength(1);
      expect(vm.$el.querySelectorAll('li .katex')).toHaveLength(2);
    });
  });
});
